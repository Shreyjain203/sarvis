import Foundation

// MARK: - Quote model

struct Quote: Codable, Hashable {
    let text: String
    let author: String?
}

// MARK: - QuoteService

/// Provides access to motivational quotes sourced from the bundle seed file
/// (`Sarvis/Resources/Quotes/seed.json`) and an optional accumulated file at
/// `Documents/processed/quotes.json` that the LLM can append to over time.
@MainActor
final class QuoteService {
    static let shared = QuoteService()

    private init() {}

    // MARK: - Public API

    /// Returns all known quotes: bundle seed + Documents-accumulated, deduped on text.
    func loadAll() -> [Quote] {
        var seen = Set<String>()
        var result: [Quote] = []

        func add(_ quotes: [Quote]) {
            for q in quotes {
                let key = q.text.lowercased()
                guard seen.insert(key).inserted else { continue }
                result.append(q)
            }
        }

        add(loadSeed())
        add(loadAccumulated())
        return result
    }

    /// Returns a uniformly random quote, or `nil` if no quotes are available.
    func random() -> Quote? {
        let all = loadAll()
        guard !all.isEmpty else { return nil }
        return all.randomElement()
    }

    // MARK: - Private helpers

    private func loadSeed() -> [Quote] {
        guard
            let url = Bundle.main.url(forResource: "seed", withExtension: "json",
                                      subdirectory: "Quotes"),
            let data = try? Data(contentsOf: url)
        else {
            // Fallback: try without subdirectory (flat bundle layout after XcodeGen copy)
            guard
                let url2 = Bundle.main.url(forResource: "seed", withExtension: "json"),
                let data2 = try? Data(contentsOf: url2)
            else { return [] }
            return (try? JSONDecoder().decode([Quote].self, from: data2)) ?? []
        }
        return (try? JSONDecoder().decode([Quote].self, from: data)) ?? []
    }

    private func loadAccumulated() -> [Quote] {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = docs
            .appendingPathComponent("processed", isDirectory: true)
            .appendingPathComponent("quotes.json")
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([Quote].self, from: data)) ?? []
    }
}
