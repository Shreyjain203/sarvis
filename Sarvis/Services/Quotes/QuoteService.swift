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

    /// Returns true if the quote (matched on lowercased text) lives in the
    /// bundled seed file. Seed quotes are NOT deletable — `delete(_:)` no-ops
    /// on them. UI can use this to suppress the swipe action visually.
    func isSeed(_ quote: Quote) -> Bool {
        let key = quote.text.lowercased()
        return loadSeed().contains { $0.text.lowercased() == key }
    }

    /// Deletes a user-captured quote from `Documents/processed/quotes.json`.
    /// Atomic write. No-ops if the quote is from the bundled seed (seed quotes
    /// are immutable). Returns true if the file was actually mutated.
    @discardableResult
    func delete(_ quote: Quote) -> Bool {
        // Seed quotes are not deletable — gracefully no-op so the UI can call
        // this without first checking `isSeed(_:)`.
        if isSeed(quote) { return false }

        let url = accumulatedFileURL()
        var accumulated = loadAccumulated()
        let key = quote.text.lowercased()
        let before = accumulated.count
        accumulated.removeAll { $0.text.lowercased() == key }
        guard accumulated.count != before else { return false }

        // Atomic rewrite; matches `data.write(to:options:.atomic)` style used
        // by other stores in this project.
        do {
            let data = try JSONEncoder().encode(accumulated)
            try data.write(to: url, options: .atomic)
            return true
        } catch {
            print("QuoteService delete error:", error)
            return false
        }
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
        let url = accumulatedFileURL()
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([Quote].self, from: data)) ?? []
    }

    private func accumulatedFileURL() -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs
            .appendingPathComponent("processed", isDirectory: true)
            .appendingPathComponent("quotes.json")
    }
}
