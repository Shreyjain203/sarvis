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

// MARK: - ClassifierService

@MainActor
final class ClassifierService: ObservableObject {
    static let shared = ClassifierService()

    @Published private(set) var isRunning = false

    private let llm = LLMService()
    private let iso = ISO8601DateFormatter()

    private init() {}

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

        // Call LLM
        guard let rawResponse = await llm.ask(systemPrompt: filledPrompt, prompt: userMessage) else {
            throw ClassifierError.llmFailed(llm.lastError ?? "No response from LLM")
        }

        // Parse JSON response
        let response = try parseResponse(rawResponse)

        // Build a lookup for unprocessed entries by UUID string
        var entryByID: [String: RawEntry] = [:]
        for entry in unprocessed {
            entryByID[entry.id.uuidString] = entry
        }

        // Distribute items
        var itemsAdded = 0
        var rawsMarked = 0

        for classifiedItem in response.items {
            guard let entry = entryByID[classifiedItem.rawId] else { continue }

            if entry.suggestedType != nil {
                // User already picked a type at capture time — dual-write already handled it.
                // Just mark raw processed; trust the user's pick.
                RawStore.shared.markProcessed(entry.id)
                rawsMarked += 1
            } else {
                // No user pick — LLM classified it. Write to processed bucket.
                let type = InputType(rawValue: classifiedItem.type) ?? .other
                let importance = importanceFromString(classifiedItem.importance)
                let dueDate = classifiedItem.dueAt.flatMap { iso.date(from: $0) }

                let item = TodoItem(
                    id: UUID(),
                    text: classifiedItem.text,
                    importance: importance,
                    isSensitive: classifiedItem.isSensitive || type == .sensitive,
                    type: type,
                    createdAt: entry.capturedAt,
                    dueAt: dueDate,
                    isDone: false,
                    notificationID: nil
                )
                TodoStore.shared.add(item)
                itemsAdded += 1

                // Mark raw processed only after successful write
                RawStore.shared.markProcessed(entry.id)
                rawsMarked += 1
            }
        }

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

        return ClassifierReport(
            itemsAdded: itemsAdded,
            rawsMarked: rawsMarked,
            notificationsScheduled: notificationsScheduled
        )
    }

    // MARK: - Private helpers

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
        // Strip markdown code fences if present
        var cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```") {
            let lines = cleaned.components(separatedBy: "\n")
            cleaned = lines.dropFirst().dropLast().joined(separator: "\n")
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
