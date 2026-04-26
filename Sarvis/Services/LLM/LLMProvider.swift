import Foundation

// Add a new provider by conforming to LLMProvider and swapping it into LLMService.
// Keep this protocol stable so models, prompts, and UI can stay the same.

enum LLMRole: String, Codable {
    case user, assistant, system
}

struct LLMMessage: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var role: LLMRole
    var content: String
    var timestamp: Date = Date()
}

struct LLMOptions {
    var model: String = "claude-opus-4-7"
    var maxTokens: Int = 1024
    var temperature: Double = 1.0
    var systemPrompt: String?
}

protocol LLMProvider {
    var displayName: String { get }
    func send(messages: [LLMMessage], options: LLMOptions) async throws -> String
}

enum LLMError: LocalizedError {
    case missingAPIKey
    case http(status: Int, body: String)
    case decoding(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Set your Anthropic API key in Settings."
        case .http(let s, let b):
            return "HTTP \(s): \(b.prefix(300))"
        case .decoding(let m):
            return "Decoding error: \(m)"
        }
    }
}
