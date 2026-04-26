import Foundation

// MARK: - Profile model

struct Profile: Codable {
    var preferences: [String: String]
    var traits: [String]
    var updatedAt: Date

    static var empty: Profile {
        Profile(preferences: [:], traits: [], updatedAt: Date())
    }
}

// MARK: - ProfileStore

/// Singleton that reads and writes `Documents/processed/profile.json` atomically.
/// Returns an empty `Profile` if the file does not yet exist.
@MainActor
final class ProfileStore: ObservableObject {
    static let shared = ProfileStore()

    @Published private(set) var profile: Profile = .empty

    private let fileURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs
            .appendingPathComponent("processed", isDirectory: true)
            .appendingPathComponent("profile.json")
    }()

    private init() {
        load()
    }

    // MARK: - Public API

    func save(_ updated: Profile) {
        profile = updated
        write(updated)
    }

    /// Merges a partial update dict into the stored profile.
    /// Recognised keys:
    /// - `"preferences"`: `[String: String]` — merged into existing preferences (new keys added, existing keys overwritten)
    /// - `"traits"`: `[String]` — appended to existing traits (no duplicates)
    func merge(_ partial: [String: Any]) {
        var updated = profile

        if let newPrefs = partial["preferences"] as? [String: String] {
            for (k, v) in newPrefs {
                updated.preferences[k] = v
            }
        }

        if let newTraits = partial["traits"] as? [String] {
            for trait in newTraits where !updated.traits.contains(trait) {
                updated.traits.append(trait)
            }
        }

        updated.updatedAt = Date()
        save(updated)
    }

    // MARK: - Private helpers

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let decoded = try? decoder.decode(Profile.self, from: data) {
            profile = decoded
        }
    }

    private func write(_ value: Profile) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        do {
            let data = try encoder.encode(value)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("ProfileStore write error:", error)
        }
    }
}
