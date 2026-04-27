import Foundation
import SwiftUI

@MainActor
final class LLMService: ObservableObject {
    static let apiKeyAccount = "anthropic_api_key"
    static let modelDefaultsKey = "llm.model"
    static let maxTokensDefaultsKey = "llm.maxTokens"

    @Published var messages: [LLMMessage] = []
    @Published var isSending = false
    @Published var lastError: String?

    var provider: LLMProvider
    var options: LLMOptions

    init(provider: LLMProvider? = nil, options: LLMOptions? = nil) {
        if let provider {
            self.provider = provider
        } else {
            let key = KeychainService.read(Self.apiKeyAccount) ?? ""
            self.provider = AnthropicProvider(apiKey: key)
        }
        if let options {
            self.options = options
        } else {
            var opts = LLMOptions()
            if let m = UserDefaults.standard.string(forKey: Self.modelDefaultsKey), !m.isEmpty {
                opts.model = m
            }
            let stored = UserDefaults.standard.integer(forKey: Self.maxTokensDefaultsKey)
            if stored > 0 { opts.maxTokens = stored }
            self.options = opts
        }
    }

    func send(_ text: String) async {
        messages.append(LLMMessage(role: .user, content: text))
        await runRequest()
    }

    func ask(systemPrompt: String, prompt: String) async -> String? {
        await ask(systemPrompt: systemPrompt, prompt: prompt, options: nil)
    }

    /// One-shot ask that lets the caller override token/temperature/model
    /// without mutating the shared `options`. Used by the classifier to bump
    /// `maxTokens` for batch JSON responses without affecting chat defaults.
    func ask(systemPrompt: String, prompt: String, options overrides: LLMOptions?) async -> String? {
        var localOptions = overrides ?? options
        localOptions.systemPrompt = systemPrompt
        let one = [LLMMessage(role: .user, content: prompt)]
        isSending = true
        lastError = nil
        defer { isSending = false }
        do {
            return try await provider.send(messages: one, options: localOptions)
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    private func runRequest() async {
        isSending = true
        lastError = nil
        defer { isSending = false }
        do {
            let reply = try await provider.send(messages: messages, options: options)
            messages.append(LLMMessage(role: .assistant, content: reply))
        } catch {
            lastError = error.localizedDescription
        }
    }

    func reload() {
        let key = KeychainService.read(Self.apiKeyAccount) ?? ""
        provider = AnthropicProvider(apiKey: key)
        if let m = UserDefaults.standard.string(forKey: Self.modelDefaultsKey), !m.isEmpty {
            options.model = m
        }
        let stored = UserDefaults.standard.integer(forKey: Self.maxTokensDefaultsKey)
        if stored > 0 { options.maxTokens = stored }
    }
}
