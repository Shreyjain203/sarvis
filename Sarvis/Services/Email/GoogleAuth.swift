import Foundation
import AuthenticationServices
import CryptoKit
import UIKit

/// Native Google OAuth via `ASWebAuthenticationSession` + URLSession.
///
/// No third-party deps. PKCE (S256) + state nonce. Refresh token persisted
/// in Keychain (`gmail_refresh_token`); access token kept in memory only.
///
/// The OAuth client ID is read at runtime from `Info.plist` under
/// `GoogleOAuthClientID`. Project.yml substitutes `$(GOOGLE_OAUTH_CLIENT_ID)`
/// at build time so the literal client ID never lives in source control.
/// Required scopes:
/// - `https://www.googleapis.com/auth/gmail.readonly`
/// - `email` (so we can show "Connected as <email>" in Settings)
/// - `profile`
@MainActor
final class GoogleAuth: NSObject, ObservableObject {

    static let shared = GoogleAuth()

    // MARK: - Keys

    static let refreshTokenKey = "gmail_refresh_token"
    private static let connectedEmailDefaultsKey = "sarvis_gmail_connected_email"
    private static let infoPlistClientIDKey = "GoogleOAuthClientID"

    // MARK: - Public state

    @Published private(set) var email: String?

    var isConnected: Bool {
        KeychainService.read(Self.refreshTokenKey) != nil
    }

    // MARK: - Internal token state

    private var accessTokenValue: String?
    private var accessTokenExpiry: Date?

    // PKCE / state values held only across one in-flight authorize() call.
    private var pendingCodeVerifier: String?
    private var pendingState: String?
    private var authSession: ASWebAuthenticationSession?

    // MARK: - Init

    override private init() {
        super.init()
        // Restore the last known connected email for display purposes.
        self.email = UserDefaults.standard.string(forKey: Self.connectedEmailDefaultsKey)
    }

    // MARK: - Configuration

    /// Reads the OAuth client ID from `Info.plist`. This is required for the
    /// flow to work; absence is a configuration error the user must fix.
    private var clientID: String? {
        guard
            let id = Bundle.main.object(forInfoDictionaryKey: Self.infoPlistClientIDKey) as? String,
            !id.isEmpty,
            !id.contains("$(")
        else {
            return nil
        }
        return id
    }

    /// Google's iOS OAuth pattern: redirect URI is the reverse-domain of the
    /// client ID, with a fixed path. Example client ID
    /// `123-abc.apps.googleusercontent.com` → redirect URI
    /// `com.googleusercontent.apps.123-abc:/oauthredirect`.
    private var redirectURI: String? {
        guard let id = clientID else { return nil }
        // Strip the ".apps.googleusercontent.com" suffix.
        let suffix = ".apps.googleusercontent.com"
        let base = id.hasSuffix(suffix) ? String(id.dropLast(suffix.count)) : id
        return "com.googleusercontent.apps.\(base):/oauthredirect"
    }

    private var callbackScheme: String? {
        guard let id = clientID else { return nil }
        let suffix = ".apps.googleusercontent.com"
        let base = id.hasSuffix(suffix) ? String(id.dropLast(suffix.count)) : id
        return "com.googleusercontent.apps.\(base)"
    }

    // MARK: - Public surface

    /// Launches the OAuth flow. Throws if the user cancels, the network fails,
    /// or the client ID is missing.
    func authorize() async throws {
        guard let clientID = clientID, let redirectURI = redirectURI, let scheme = callbackScheme else {
            throw EmailError.authFailed("OAuth client ID missing in Info.plist (GoogleOAuthClientID). See docs/phase-2.md §2.2 setup checklist.")
        }

        // Build PKCE verifier + S256 challenge.
        let codeVerifier = Self.randomURLSafe(length: 64)
        let codeChallenge = Self.s256Challenge(for: codeVerifier)
        let stateNonce = Self.randomURLSafe(length: 32)
        pendingCodeVerifier = codeVerifier
        pendingState = stateNonce

        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        let scopes = [
            "https://www.googleapis.com/auth/gmail.readonly",
            "https://www.googleapis.com/auth/userinfo.email",
            "https://www.googleapis.com/auth/userinfo.profile"
        ].joined(separator: " ")
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scopes),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: stateNonce),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent")
        ]
        guard let url = components.url else {
            throw EmailError.authFailed("Failed to construct OAuth URL")
        }

        let callbackURL: URL = try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: scheme
            ) { url, error in
                if let error {
                    continuation.resume(throwing: EmailError.authFailed(error.localizedDescription))
                    return
                }
                guard let url else {
                    continuation.resume(throwing: EmailError.authFailed("No callback URL"))
                    return
                }
                continuation.resume(returning: url)
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            self.authSession = session
            if !session.start() {
                continuation.resume(throwing: EmailError.authFailed("Could not start ASWebAuthenticationSession"))
            }
        }

        // Validate state and extract code.
        guard
            let comps = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
            let returnedState = comps.queryItems?.first(where: { $0.name == "state" })?.value,
            returnedState == stateNonce,
            let code = comps.queryItems?.first(where: { $0.name == "code" })?.value
        else {
            throw EmailError.authFailed("OAuth callback missing/invalid code or state")
        }

        // Exchange code for tokens.
        try await exchangeCode(code, codeVerifier: codeVerifier, redirectURI: redirectURI, clientID: clientID)

        // Fetch the userinfo to populate the "Connected as <email>" label.
        if let fetched = try? await fetchUserInfoEmail() {
            self.email = fetched
            UserDefaults.standard.set(fetched, forKey: Self.connectedEmailDefaultsKey)
        }

        pendingCodeVerifier = nil
        pendingState = nil
        authSession = nil
    }

    /// Returns a valid access token, refreshing if expired or unset.
    /// Throws `EmailError.notConnected` if we have no refresh token at all.
    func accessToken() async throws -> String {
        if let token = accessTokenValue,
           let expiry = accessTokenExpiry,
           expiry > Date().addingTimeInterval(30) {
            return token
        }
        // Otherwise refresh.
        guard let refresh = KeychainService.read(Self.refreshTokenKey),
              let clientID = clientID else {
            throw EmailError.notConnected
        }
        try await refreshAccessToken(using: refresh, clientID: clientID)
        guard let token = accessTokenValue else {
            throw EmailError.authFailed("Refresh succeeded but no access token returned")
        }
        return token
    }

    /// Disconnects: removes refresh token from Keychain, clears in-memory
    /// access token, and best-effort revokes via Google's revoke endpoint.
    func disconnect() {
        let refresh = KeychainService.read(Self.refreshTokenKey)
        KeychainService.delete(Self.refreshTokenKey)
        accessTokenValue = nil
        accessTokenExpiry = nil
        email = nil
        UserDefaults.standard.removeObject(forKey: Self.connectedEmailDefaultsKey)

        // Best-effort revoke. Don't await; don't surface errors.
        if let token = refresh, let url = URL(string: "https://oauth2.googleapis.com/revoke?token=\(token)") {
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            URLSession.shared.dataTask(with: req).resume()
        }
    }

    // MARK: - Token endpoints

    private func exchangeCode(
        _ code: String,
        codeVerifier: String,
        redirectURI: String,
        clientID: String
    ) async throws {
        var req = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        req.httpMethod = "POST"
        req.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = Self.formEncode([
            "code": code,
            "client_id": clientID,
            "code_verifier": codeVerifier,
            "redirect_uri": redirectURI,
            "grant_type": "authorization_code"
        ])
        req.httpBody = body.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let bodyStr = String(data: data, encoding: .utf8) ?? ""
            throw EmailError.authFailed("Token exchange failed: \(bodyStr.prefix(200))")
        }
        let token = try JSONDecoder().decode(TokenResponse.self, from: data)
        if let refresh = token.refresh_token {
            try? KeychainService.save(refresh, for: Self.refreshTokenKey)
        }
        accessTokenValue = token.access_token
        accessTokenExpiry = Date().addingTimeInterval(TimeInterval(token.expires_in ?? 3000))
    }

    private func refreshAccessToken(using refreshToken: String, clientID: String) async throws {
        var req = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        req.httpMethod = "POST"
        req.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = Self.formEncode([
            "refresh_token": refreshToken,
            "client_id": clientID,
            "grant_type": "refresh_token"
        ])
        req.httpBody = body.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let bodyStr = String(data: data, encoding: .utf8) ?? ""
            throw EmailError.authFailed("Token refresh failed: \(bodyStr.prefix(200))")
        }
        let token = try JSONDecoder().decode(TokenResponse.self, from: data)
        accessTokenValue = token.access_token
        accessTokenExpiry = Date().addingTimeInterval(TimeInterval(token.expires_in ?? 3000))
    }

    // MARK: - User info

    private struct UserInfo: Decodable {
        let email: String?
    }

    /// Fetches `https://www.googleapis.com/oauth2/v2/userinfo` and returns
    /// the email field. Used once at authorize() time for display.
    func fetchUserInfoEmail() async throws -> String? {
        let token = try await accessToken()
        var req = URLRequest(url: URL(string: "https://www.googleapis.com/oauth2/v2/userinfo")!)
        req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            return nil
        }
        let info = try JSONDecoder().decode(UserInfo.self, from: data)
        return info.email
    }

    // MARK: - Helpers

    private struct TokenResponse: Decodable {
        let access_token: String
        let expires_in: Int?
        let refresh_token: String?
        let token_type: String?
        let scope: String?
    }

    private static func randomURLSafe(length: Int) -> String {
        var bytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, length, &bytes)
        return Data(bytes).base64URLEncodedString()
    }

    private static func s256Challenge(for verifier: String) -> String {
        let hash = SHA256.hash(data: Data(verifier.utf8))
        return Data(hash).base64URLEncodedString()
    }

    private static func formEncode(_ pairs: [String: String]) -> String {
        pairs.map { key, value in
            let k = key.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? key
            let v = value.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? value
            return "\(k)=\(v)"
        }.joined(separator: "&")
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension GoogleAuth: ASWebAuthenticationPresentationContextProviding {
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // Best-effort: return the first foreground key window. We're on the
        // main actor when authorize() invokes this in practice; the nonisolated
        // attribute is required by the protocol.
        let anchor = MainActor.assumeIsolated {
            UIApplication.shared
                .connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }
                ?? ASPresentationAnchor()
        }
        return anchor
    }
}

// MARK: - Base64URL helper

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

private extension CharacterSet {
    static let urlQueryValueAllowed: CharacterSet = {
        var s = CharacterSet.urlQueryAllowed
        s.remove(charactersIn: "+&=?/#")
        return s
    }()
}
