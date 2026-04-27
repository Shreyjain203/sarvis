import Foundation

// MARK: - Report

struct ClassifierReport {
    let itemsAdded: Int
    let rawsMarked: Int
    let notificationsScheduled: Int
}

// MARK: - LLM response shapes

private struct ClassifierResponse: Decodable {
    let items: [ClassifierItem]
    let notifications: [ClassifierNotification]
    let profileDeltas: ProfileDeltas?
}

private struct ClassifierItem: Decodable {
    let rawId: String
    let type: String
    let text: String
    let importance: String
    let dueAt: String?
    let isSensitive: Bool
}

private struct ClassifierNotification: Decodable {
    let title: String
    let body: String
    let fireAt: String
}

private struct ProfileDeltas: Decodable {
    let preferences: [String: String]?
    let traits: [String]?
}

// MARK: - Debug record

/// In-memory snapshot of the most recent classifier round, surfaced via the
/// hidden Debug screen in Settings. Not persisted to disk — only the most
/// recent run is kept so the user can inspect what the LLM actually did.
struct ClassifierDebugRecord {
    /// One entry per classified item, capturing the resolution decision so the
    /// user can see why an item ended up where it did.
    struct DistributionEntry {
        /// First ~80 chars of the raw entry's text.
        let rawSnippet: String
        /// Resolved final type (after suggestedType-vs-LLM reconciliation).
        let resolvedType: String
        /// Outcome — "added", or "skipped: <reason>".
        let action: String
    }

    let timestamp: Date
    /// Snapshot of every raw entry fed into this round.
    let inputRaws: [RawEntry]
    /// Final substituted system prompt.
    let systemPrompt: String
    /// Final user message body.
    let userPrompt: String
    /// Raw LLM response string (nil if the LLM call returned nil).
    let rawResponse: String?
    /// Pretty-printed JSON of the parsed response, or nil if parse failed.
    let parsedJSONPretty: String?
    /// Per-item routing decisions.
    let distribution: [DistributionEntry]
    /// Number of TodoItems written this round.
    let itemsAdded: Int
    /// Error description if the round threw.
    let errorDescription: String?
}

// MARK: - ClassifierService

@MainActor
final class ClassifierService: ObservableObject {
    static let shared = ClassifierService()

    @Published private(set) var isRunning = false

    /// Most recent classifier round — populated on both success and failure.
    /// Surfaced via `ClassifierDebugView` (Settings → Debug).
    @Published private(set) var lastRun: ClassifierDebugRecord?

    private let llm = LLMService()
    private let iso = ISO8601DateFormatter()

    private init() {}

    /// The last error string surfaced by the underlying `LLMService`, if any.
    /// Useful for the UI to show the real cause when a run completes with
    /// zero items added.
    var lastLLMError: String? { llm.lastError }

    /// Reads all unprocessed raw entries, sends them to the LLM classifier,
    /// distributes outputs into the appropriate processed buckets, and returns
    /// a summary report. Throws on LLM or JSON-parsing failures; raws are
    /// never marked processed unless their processed item was successfully written.
    func classifyUnprocessed() async throws -> ClassifierReport {
        guard !isRunning else {
            throw ClassifierError.alreadyRunning
        }
        isRunning = true
        defer { isRunning = false }

        let unprocessed = RawStore.shared.unprocessed()
        guard !unprocessed.isEmpty else {
            // Nothing to do — also clear any stale last-run for clarity.
            return ClassifierReport(itemsAdded: 0, rawsMarked: 0, notificationsScheduled: 0)
        }

        // Build prompt
        let systemPrompt = PromptLibrary.body(
            for: "capture_classify",
            fallback: "Classify each raw entry. Return JSON only with shape: {\"items\":[{\"rawId\":\"\",\"type\":\"task\",\"text\":\"\",\"importance\":\"medium\",\"dueAt\":null,\"isSensitive\":false}],\"notifications\":[],\"profileDeltas\":{\"preferences\":{},\"traits\":[]}}"
        )

        let entriesJSON = buildEntriesJSON(unprocessed)
        let profileJSON = buildProfileJSON()
        let today = iso.string(from: Date())

        // Substitute template variables
        let filledPrompt = systemPrompt
            .replacingOccurrences(of: "{{entries}}", with: entriesJSON)
            .replacingOccurrences(of: "{{profile}}", with: profileJSON)
            .replacingOccurrences(of: "{{today}}", with: today)

        let userMessage = "Entries:\n\(entriesJSON)\n\nProfile:\n\(profileJSON)\n\nToday: \(today)"

        // Local debug-record accumulators. We populate `lastRun` in any exit
        // path (success, throw, even rethrow) so the user always sees the
        // most recent attempt.
        var rawResponseForDebug: String?
        var parsedPrettyForDebug: String?
        var distributionForDebug: [ClassifierDebugRecord.DistributionEntry] = []
        var itemsAddedForDebug = 0

        func recordDebug(error: Error?) {
            self.lastRun = ClassifierDebugRecord(
                timestamp: Date(),
                inputRaws: unprocessed,
                systemPrompt: filledPrompt,
                userPrompt: userMessage,
                rawResponse: rawResponseForDebug,
                parsedJSONPretty: parsedPrettyForDebug,
                distribution: distributionForDebug,
                itemsAdded: itemsAddedForDebug,
                errorDescription: error.map { ($0 as? LocalizedError)?.errorDescription ?? "\($0)" }
            )
        }

        do {
            // Call LLM with a higher token budget than the chat default — batch
            // classification can produce large JSON, and 1024 truncates it.
            var classifierOptions = llm.options
            classifierOptions.maxTokens = max(classifierOptions.maxTokens, 4096)
            guard let rawResponse = await llm.ask(
                systemPrompt: filledPrompt,
                prompt: userMessage,
                options: classifierOptions
            ) else {
                let err = ClassifierError.llmFailed(llm.lastError ?? "No response from LLM")
                recordDebug(error: err)
                throw err
            }
            rawResponseForDebug = rawResponse

            // Parse JSON response
            let response: ClassifierResponse
            do {
                response = try parseResponse(rawResponse)
            } catch {
                recordDebug(error: error)
                throw error
            }
            parsedPrettyForDebug = prettyPrint(response: response)

            // Build a lookup for unprocessed entries by UUID string
            var entryByID: [String: RawEntry] = [:]
            for entry in unprocessed {
                entryByID[entry.id.uuidString] = entry
            }

            // Distribute items
            var itemsAdded = 0
            var rawsMarked = 0
            var matchedRawIDs = Set<String>()

            for classifiedItem in response.items {
                guard let entry = entryByID[classifiedItem.rawId] else {
                    distributionForDebug.append(.init(
                        rawSnippet: snippet(classifiedItem.rawId),
                        resolvedType: classifiedItem.type,
                        action: "skipped: rawId not in this batch"
                    ))
                    continue
                }
                matchedRawIDs.insert(classifiedItem.rawId)

                // Type resolution: respect the user's pick at capture time. The
                // LLM's cleaned text / importance / dueAt / isSensitive still
                // apply.
                let resolvedType: InputType
                if let userPick = entry.suggestedType {
                    resolvedType = userPick
                } else {
                    resolvedType = InputType(rawValue: classifiedItem.type) ?? .other
                }

                let importance = importanceFromString(classifiedItem.importance)
                var dueDate = classifiedItem.dueAt.flatMap { iso.date(from: $0) } ?? entry.dueAt

                // Safety net: every task must carry a date so the tile bucketing
                // never sees a nil dueAt. Default to today + 7d 09:00 when the
                // LLM (or anything upstream) failed to produce one.
                var defaultedDueAt = false
                if resolvedType == .task && dueDate == nil {
                    let cal = Calendar.current
                    let base = cal.date(byAdding: .day, value: 7, to: Date()) ?? Date()
                    var comps = cal.dateComponents([.year, .month, .day], from: base)
                    comps.hour = 9
                    comps.minute = 0
                    dueDate = cal.date(from: comps) ?? base
                    defaultedDueAt = true
                }

                let item = TodoItem(
                    id: UUID(),
                    text: classifiedItem.text,
                    importance: importance,
                    isSensitive: classifiedItem.isSensitive || resolvedType == .sensitive,
                    type: resolvedType,
                    createdAt: entry.capturedAt,
                    dueAt: dueDate,
                    isDone: false,
                    notificationID: entry.notificationID
                )
                TodoStore.shared.add(item)
                itemsAdded += 1

                // Mark raw processed only after the TodoItem write succeeds.
                RawStore.shared.markProcessed(entry.id)
                rawsMarked += 1

                distributionForDebug.append(.init(
                    rawSnippet: snippet(entry.text),
                    resolvedType: resolvedType.rawValue,
                    action: defaultedDueAt
                        ? "added (task without dueAt → defaulted to +7d)"
                        : "added"
                ))
            }

            // Note any unprocessed raws the LLM didn't return in its items list.
            for entry in unprocessed where !matchedRawIDs.contains(entry.id.uuidString) {
                distributionForDebug.append(.init(
                    rawSnippet: snippet(entry.text),
                    resolvedType: entry.suggestedType?.rawValue ?? "—",
                    action: "skipped: not returned by LLM"
                ))
            }

            itemsAddedForDebug = itemsAdded

            // Schedule notifications
            var notificationsScheduled = 0
            for notification in response.notifications {
                guard let fireDate = iso.date(from: notification.fireAt),
                      fireDate > Date() else { continue }
                do {
                    try await NotificationService.shared.schedule(
                        title: notification.title,
                        body: notification.body,
                        at: fireDate
                    )
                    notificationsScheduled += 1
                } catch {
                    print("ClassifierService: notification scheduling failed:", error)
                }
            }

            // Apply profile deltas
            if let deltas = response.profileDeltas {
                var partial: [String: Any] = [:]
                if let prefs = deltas.preferences { partial["preferences"] = prefs }
                if let traits = deltas.traits { partial["traits"] = traits }
                if !partial.isEmpty {
                    ProfileStore.shared.merge(partial)
                }
            }

            recordDebug(error: nil)

            return ClassifierReport(
                itemsAdded: itemsAdded,
                rawsMarked: rawsMarked,
                notificationsScheduled: notificationsScheduled
            )
        } catch {
            // Any error path that didn't already record (e.g. an unexpected
            // throw from the deeper code) gets captured here.
            if lastRun?.timestamp == nil || (lastRun.map { Date().timeIntervalSince($0.timestamp) > 1 } ?? true) {
                recordDebug(error: error)
            }
            throw error
        }
    }

    // MARK: - Private helpers

    private func snippet(_ s: String, max: Int = 80) -> String {
        let trimmed = s.replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespaces)
        if trimmed.count <= max { return trimmed }
        return String(trimmed.prefix(max)) + "…"
    }

    private func prettyPrint(response: ClassifierResponse) -> String? {
        // We can't directly re-encode the private `ClassifierResponse` without
        // making it Encodable. Instead, build a `[String: Any]` mirror so we
        // can run it through `JSONSerialization` for pretty output.
        var items: [[String: Any]] = []
        for it in response.items {
            var d: [String: Any] = [
                "rawId": it.rawId,
                "type": it.type,
                "text": it.text,
                "importance": it.importance,
                "isSensitive": it.isSensitive
            ]
            if let due = it.dueAt { d["dueAt"] = due }
            items.append(d)
        }
        var notifs: [[String: Any]] = []
        for n in response.notifications {
            notifs.append([
                "title": n.title,
                "body": n.body,
                "fireAt": n.fireAt
            ])
        }
        var deltas: [String: Any] = [:]
        if let p = response.profileDeltas {
            if let prefs = p.preferences { deltas["preferences"] = prefs }
            if let traits = p.traits { deltas["traits"] = traits }
        }
        let dict: [String: Any] = [
            "items": items,
            "notifications": notifs,
            "profileDeltas": deltas
        ]
        guard let data = try? JSONSerialization.data(
            withJSONObject: dict,
            options: [.prettyPrinted, .sortedKeys]
        ),
              let str = String(data: data, encoding: .utf8) else { return nil }
        return str
    }

    private func buildEntriesJSON(_ entries: [RawEntry]) -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        let dicts = entries.map { e -> [String: String] in
            var d: [String: String] = [
                "id": e.id.uuidString,
                "text": e.text,
                "importance": importanceToString(e.importance),
                "isSensitive": e.isSensitive ? "true" : "false",
                "capturedAt": iso.string(from: e.capturedAt)
            ]
            if let t = e.suggestedType { d["suggestedType"] = t.rawValue }
            if let due = e.dueAt { d["dueAt"] = iso.string(from: due) }
            return d
        }
        guard let data = try? JSONSerialization.data(withJSONObject: dicts, options: .prettyPrinted),
              let str = String(data: data, encoding: .utf8) else { return "[]" }
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

    private func parseResponse(_ raw: String) throws -> ClassifierResponse {
        // Strip markdown code fences if present.
        var cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```") {
            let lines = cleaned.components(separatedBy: "\n")
            cleaned = lines.dropFirst().dropLast().joined(separator: "\n")
        }

        // Slice between the FIRST `{` and the LAST `}` so we survive
        // any preamble ("Here's the JSON:") or trailing prose.
        if let firstBrace = cleaned.firstIndex(of: "{"),
           let lastBrace = cleaned.lastIndex(of: "}"),
           firstBrace <= lastBrace {
            cleaned = String(cleaned[firstBrace...lastBrace])
        }

        guard let data = cleaned.data(using: .utf8) else {
            throw ClassifierError.badJSON("Could not encode response as UTF-8")
        }
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(ClassifierResponse.self, from: data)
        } catch {
            throw ClassifierError.badJSON(error.localizedDescription)
        }
    }

    private func importanceFromString(_ s: String) -> Importance {
        switch s.lowercased() {
        case "low":    return .low
        case "high":   return .high
        case "critical": return .critical
        default:       return .medium
        }
    }

    private func importanceToString(_ i: Importance) -> String {
        switch i {
        case .low:      return "low"
        case .medium:   return "medium"
        case .high:     return "high"
        case .critical: return "high"
        }
    }
}

// MARK: - Errors

enum ClassifierError: LocalizedError {
    case alreadyRunning
    case llmFailed(String)
    case badJSON(String)

    var errorDescription: String? {
        switch self {
        case .alreadyRunning:   return "Classifier is already running."
        case .llmFailed(let m): return "LLM error: \(m)"
        case .badJSON(let m):   return "JSON parse error: \(m)"
        }
    }
}
