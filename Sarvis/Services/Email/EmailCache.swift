import Foundation

/// On-disk cache for fetched email metadata. Mirrors `NewsCache`.
/// Path: `Documents/cache/email/<YYYY-MM-DD>.json`.
struct EmailCache {

    private static let cacheDir: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("cache/email", isDirectory: true)
    }()

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    // MARK: - Public API

    func saveToday(_ items: [EmailItem]) {
        save(items, for: Date())
    }

    func loadToday() -> [EmailItem]? {
        load(for: Date())
    }

    func save(_ items: [EmailItem], for date: Date) {
        let dir = Self.cacheDir
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let data = try Self.encoder.encode(items)
            let fileURL = dir.appendingPathComponent(Self.filename(for: date))
            // Atomic write: temp + replace.
            let tmpURL = dir.appendingPathComponent(UUID().uuidString + ".tmp")
            try data.write(to: tmpURL, options: .atomic)
            _ = try FileManager.default.replaceItemAt(fileURL, withItemAt: tmpURL)
        } catch {
            print("EmailCache: write failed:", error)
        }
    }

    func load(for date: Date) -> [EmailItem]? {
        let url = Self.cacheDir.appendingPathComponent(Self.filename(for: date))
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? Self.decoder.decode([EmailItem].self, from: data)
    }

    /// Removes all email cache files. Used on disconnect.
    func clearAll() {
        let fm = FileManager.default
        guard let urls = try? fm.contentsOfDirectory(at: Self.cacheDir, includingPropertiesForKeys: nil) else { return }
        for url in urls {
            try? fm.removeItem(at: url)
        }
    }

    // MARK: - Helpers

    private static func filename(for date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return "\(f.string(from: date)).json"
    }
}
