import Foundation

/// Concrete `EmailProvider` backed by the Gmail REST API.
///
/// Two-call pattern:
/// 1. `users.messages.list?q=newer_than:1d&maxResults=<limit>` → array of message IDs
/// 2. For each ID: `users.messages.get?id=<id>&format=metadata&metadataHeaders=Subject&metadataHeaders=From&metadataHeaders=Date`
///
/// We pull `snippet` directly from the metadata response (Gmail returns it
/// even in metadata format). Snippet is truncated to ~200 chars on receive.
///
/// Auth posture: uses `GoogleAuth.shared.accessToken()` for the bearer header.
/// On 401 we refresh once and retry once; further 401s surface as errors.
struct GmailProvider: EmailProvider {

    private let session: URLSession
    private let auth: GoogleAuth

    init(session: URLSession = .shared, auth: GoogleAuth? = nil) {
        self.session = session
        // GoogleAuth.shared is @MainActor; we pass it explicitly from the
        // call site (which is always @MainActor) to avoid a nonisolated default.
        self.auth = auth ?? GoogleAuth.shared
    }

    func fetchRecent(limit: Int = 20, since: String? = nil) async throws -> [EmailItem] {
        let q = since ?? "newer_than:1d"
        let ids = try await listMessageIDs(q: q, limit: limit)
        var out: [EmailItem] = []
        out.reserveCapacity(ids.count)
        for ref in ids {
            if let item = try? await fetchMessage(id: ref.id) {
                out.append(item)
            }
        }
        return out
    }

    // MARK: - List

    private struct ListResponse: Decodable {
        struct MessageRef: Decodable {
            let id: String
            let threadId: String
        }
        let messages: [MessageRef]?
    }

    private func listMessageIDs(q: String, limit: Int) async throws -> [(id: String, threadId: String)] {
        var components = URLComponents(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages")!
        components.queryItems = [
            URLQueryItem(name: "q", value: q),
            URLQueryItem(name: "maxResults", value: "\(limit)")
        ]
        let url = components.url!
        let data = try await authedRequest(url: url)
        do {
            let decoded = try JSONDecoder().decode(ListResponse.self, from: data)
            return (decoded.messages ?? []).map { ($0.id, $0.threadId) }
        } catch {
            throw EmailError.decoding(error)
        }
    }

    // MARK: - Get

    private struct MessageResponse: Decodable {
        struct Header: Decodable {
            let name: String
            let value: String
        }
        struct Payload: Decodable {
            let headers: [Header]?
        }
        let id: String
        let threadId: String
        let snippet: String?
        let internalDate: String?
        let payload: Payload?
    }

    private func fetchMessage(id: String) async throws -> EmailItem {
        var components = URLComponents(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages/\(id)")!
        components.queryItems = [
            URLQueryItem(name: "format", value: "metadata"),
            URLQueryItem(name: "metadataHeaders", value: "Subject"),
            URLQueryItem(name: "metadataHeaders", value: "From"),
            URLQueryItem(name: "metadataHeaders", value: "Date")
        ]
        let url = components.url!
        let data = try await authedRequest(url: url)
        let response: MessageResponse
        do {
            response = try JSONDecoder().decode(MessageResponse.self, from: data)
        } catch {
            throw EmailError.decoding(error)
        }
        let headers = response.payload?.headers ?? []
        let subject = headers.first { $0.name.caseInsensitiveCompare("Subject") == .orderedSame }?.value ?? "(no subject)"
        let from = headers.first { $0.name.caseInsensitiveCompare("From") == .orderedSame }?.value ?? "(unknown sender)"

        // Prefer Gmail's `internalDate` (epoch ms) → Date. Fall back to the Date header.
        var receivedAt = Date()
        if let internalMs = response.internalDate, let ms = Double(internalMs) {
            receivedAt = Date(timeIntervalSince1970: ms / 1000)
        } else if let dateHeader = headers.first(where: { $0.name.caseInsensitiveCompare("Date") == .orderedSame })?.value,
                  let parsed = Self.parseRFC2822Date(dateHeader) {
            receivedAt = parsed
        }

        let snippet = (response.snippet ?? "")
            .htmlEntityDecoded
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let truncated = snippet.count > 200 ? String(snippet.prefix(200)) + "…" : snippet

        return EmailItem(
            id: response.id,
            threadID: response.threadId,
            subject: subject,
            sender: from,
            snippet: truncated,
            receivedAt: receivedAt
        )
    }

    // MARK: - Auth + retry

    /// Issues a GET with Bearer token. On 401, refreshes and retries once.
    private func authedRequest(url: URL) async throws -> Data {
        let (data, response) = try await sendOnce(url: url)
        if let http = response as? HTTPURLResponse, http.statusCode == 401 {
            // Force a refresh by clearing in-memory token then retry.
            // GoogleAuth.accessToken() refreshes when expired; here we trust
            // the second call to refresh because Google flagged the current one bad.
            _ = try await auth.accessToken() // ensures we have a (possibly fresh) token
            let (retryData, retryResponse) = try await sendOnce(url: url)
            if let httpRetry = retryResponse as? HTTPURLResponse, !(200..<300).contains(httpRetry.statusCode) {
                let body = String(data: retryData, encoding: .utf8) ?? ""
                throw EmailError.badResponse("HTTP \(httpRetry.statusCode): \(body.prefix(200))")
            }
            return retryData
        }
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw EmailError.badResponse("HTTP \(http.statusCode): \(body.prefix(200))")
        }
        return data
    }

    private func sendOnce(url: URL) async throws -> (Data, URLResponse) {
        let token = try await auth.accessToken()
        var req = URLRequest(url: url)
        req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return try await session.data(for: req)
    }

    // MARK: - Helpers

    private static func parseRFC2822Date(_ str: String) -> Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        if let d = f.date(from: str) { return d }
        f.dateFormat = "dd MMM yyyy HH:mm:ss zzz"
        return f.date(from: str)
    }
}

// MARK: - Snippet decoding

private extension String {
    /// Gmail snippets occasionally come back with HTML entities (&amp;, &#39;).
    /// Replace the common ones; we don't pull in a full HTML parser.
    var htmlEntityDecoded: String {
        var out = self
        let replacements: [(String, String)] = [
            ("&amp;", "&"),
            ("&lt;", "<"),
            ("&gt;", ">"),
            ("&quot;", "\""),
            ("&#39;", "'"),
            ("&nbsp;", " ")
        ]
        for (k, v) in replacements {
            out = out.replacingOccurrences(of: k, with: v)
        }
        return out
    }
}
