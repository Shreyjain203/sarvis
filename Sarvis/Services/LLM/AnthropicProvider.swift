import Foundation

struct AnthropicProvider: LLMProvider {
    let apiKey: String
    var displayName: String { "Anthropic" }

    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private let apiVersion = "2023-06-01"

    func send(messages: [LLMMessage], options: LLMOptions) async throws -> String {
        guard !apiKey.isEmpty else { throw LLMError.missingAPIKey }

        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.timeoutInterval = 60

        let payload = Request(
            model: options.model,
            max_tokens: options.maxTokens,
            temperature: options.temperature,
            system: options.systemPrompt,
            messages: messages
                .filter { $0.role != .system }
                .map { Request.Msg(role: $0.role.rawValue, content: $0.content) }
        )
        req.httpBody = try JSONEncoder().encode(payload)

        let (data, resp) = try await URLSession.shared.data(for: req)
        let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            throw LLMError.http(status: status, body: String(data: data, encoding: .utf8) ?? "")
        }

        do {
            let decoded = try JSONDecoder().decode(Response.self, from: data)
            return decoded.content.compactMap(\.text).joined()
        } catch {
            throw LLMError.decoding(error.localizedDescription)
        }
    }

    private struct Request: Encodable {
        let model: String
        let max_tokens: Int
        let temperature: Double
        let system: String?
        let messages: [Msg]
        struct Msg: Encodable { let role: String; let content: String }
    }

    private struct Response: Decodable {
        let content: [Block]
        struct Block: Decodable { let type: String; let text: String? }
    }
}
