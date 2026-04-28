import Foundation

/// Orchestrates the morning email pipeline:
/// 1. Fetch recent messages via `GmailProvider`
/// 2. Cache them locally (`EmailCache`)
/// 3. Ask the LLM to classify into important / fyi / promo + extract actions
/// 4. Persist the result as an `EmailDigest` artifact under
///    `Documents/processed/email/<YYYY-MM-DD>.json`
///
/// Reading flow (UI side) → use `EmailDigestService.shared.todaysDigest()`.
@MainActor
final class EmailDigestService: ObservableObject {

    static let shared = EmailDigestService()

    @Published private(set) var lastError: Error?
    @Published private(set) var isRunning = false

    private let provider: EmailProvider
    private let cache: EmailCache
    private let auth: GoogleAuth
    private let llm: LLMService
    private let iso: ISO8601DateFormatter

    init(
        provider: EmailProvider? = nil,
        cache: EmailCache = EmailCache(),
        auth: GoogleAuth = .shared,
        llm: LLMService? = nil
    ) {
        self.provider = provider ?? GmailProvider()
        self.cache = cache
        self.auth = auth
        self.llm = llm ?? LLMService()
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        self.iso = f
    }

    // MARK: - Public reads

    /// Returns today's processed digest if we already have one cached on disk.
    func todaysDigest() -> EmailDigest? {
        DailyArtifactStore.shared.read(folder: "email", date: Date())
    }

    // MARK: - Public refresh

    /// Fetches recent email, classifies via the LLM, and writes the digest.
    /// No-op (returns early) if the user hasn't connected Gmail.
    @discardableResult
    func refreshToday(limit: Int = 20) async throws -> EmailDigest {
        guard !isRunning else { return todaysDigest() ?? EmailDigest(date: Date(), important: [], fyi: [], promo: [], actions: []) }
        guard auth.isConnected else { throw EmailError.notConnected }
        isRunning = true
        defer { isRunning = false }

        do {
            // 1. Fetch
            let items = try await provider.fetchRecent(limit: limit, since: "newer_than:1d")
            cache.saveToday(items)

            // 2. Classify
            let digest = try await classify(items)

            // 3. Persist
            DailyArtifactStore.shared.write(digest, folder: "email", date: Date())
            lastError = nil
            return digest
        } catch {
            lastError = error
            throw error
        }
    }

    // MARK: - Classification

    private struct ClassifyResponse: Decodable {
        let important: [String]?
        let fyi: [String]?
        let promo: [String]?
        let actions: [ActionDTO]?

        struct ActionDTO: Decodable {
            let text: String
            let sourceMessageID: String?
            let sourceMessageId: String?
            let dueAt: String?
        }
    }

    private func classify(_ items: [EmailItem]) async throws -> EmailDigest {
        // Empty inbox → empty digest, no LLM call.
        guard !items.isEmpty else {
            return EmailDigest(date: Date(), important: [], fyi: [], promo: [], actions: [])
        }

        let promptBody = PromptLibrary.body(
            for: "email_classify",
            fallback: "Classify each email into important/fyi/promo. Return JSON {\"important\":[],\"fyi\":[],\"promo\":[],\"actions\":[]}."
        )

        let emailsJSON = encodeEmailsJSON(items)
        let profileJSON = buildProfileJSON()
        let today = iso.string(from: Date())

        let filledPrompt = promptBody
            .replacingOccurrences(of: "{{emails}}", with: emailsJSON)
            .replacingOccurrences(of: "{{profile}}", with: profileJSON)
            .replacingOccurrences(of: "{{today}}", with: today)

        let userMessage = "Emails:\n\(emailsJSON)\n\nProfile:\n\(profileJSON)\n\nToday: \(today)"

        var options = llm.options
        options.maxTokens = max(options.maxTokens, 4096)

        guard let raw = await llm.ask(
            systemPrompt: filledPrompt,
            prompt: userMessage,
            options: options
        ) else {
            throw EmailError.badResponse(llm.lastError ?? "LLM returned no response")
        }

        let parsed = try parseClassifyResponse(raw)

        // Build a lookup by ID, then fan items into buckets.
        var byID: [String: EmailItem] = [:]
        for it in items { byID[it.id] = it }

        let important = (parsed.important ?? []).compactMap { byID[$0] }
        let fyi = (parsed.fyi ?? []).compactMap { byID[$0] }
        let promo = (parsed.promo ?? []).compactMap { byID[$0] }
        let actions: [EmailAction] = (parsed.actions ?? []).compactMap { dto in
            let id = dto.sourceMessageID ?? dto.sourceMessageId ?? ""
            // Drop actions whose source isn't in this batch — protects against hallucinated IDs.
            guard byID[id] != nil else { return nil }
            let dueDate = dto.dueAt.flatMap { ISO8601DateFormatter.fullDateFormatter.date(from: $0) }
            return EmailAction(text: dto.text, sourceMessageID: id, dueAt: dueDate)
        }

        return EmailDigest(
            date: Date(),
            important: important,
            fyi: fyi,
            promo: promo,
            actions: actions
        )
    }

    // MARK: - JSON helpers

    private func encodeEmailsJSON(_ items: [EmailItem]) -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(items),
              let str = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return str
    }

    private func buildProfileJSON() -> String {
        let profile = ProfileStore.shared.profile
        let dict: [String: Any] = [
            "preferences": profile.preferences,
            "traits": profile.traits
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted),
              let str = String(data: data, encoding: .utf8) else { return "{}" }
        return str
    }

    /// Parses the LLM response. Mirrors `ClassifierService.parseResponse` —
    /// strips fences and slices between first `{` and last `}` so preamble/
    /// postamble doesn't kill us.
    private func parseClassifyResponse(_ raw: String) throws -> ClassifyResponse {
        var cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```") {
            let lines = cleaned.components(separatedBy: "\n")
            cleaned = lines.dropFirst().dropLast().joined(separator: "\n")
        }
        if let firstBrace = cleaned.firstIndex(of: "{"),
           let lastBrace = cleaned.lastIndex(of: "}"),
           firstBrace <= lastBrace {
            cleaned = String(cleaned[firstBrace...lastBrace])
        }
        guard let data = cleaned.data(using: .utf8) else {
            throw EmailError.badResponse("Could not encode LLM response as UTF-8")
        }
        do {
            return try JSONDecoder().decode(ClassifyResponse.self, from: data)
        } catch {
            throw EmailError.decoding(error)
        }
    }
}

private extension ISO8601DateFormatter {
    static let fullDateFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
}
