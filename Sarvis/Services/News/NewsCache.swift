import Foundation

struct NewsCache {
    private static let cacheDir: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("cache/news", isDirectory: true)
    }()

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    // MARK: - Public API

    func write(_ articles: [NewsArticle], for date: Date) throws {
        let dir = Self.cacheDir
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let fileURL = dir.appendingPathComponent(Self.filename(for: date))
        let data = try Self.encoder.encode(articles)

        // Atomic write: write to temp, then move
        let tmpURL = dir.appendingPathComponent(UUID().uuidString + ".tmp")
        try data.write(to: tmpURL, options: .atomic)
        _ = try FileManager.default.replaceItemAt(fileURL, withItemAt: tmpURL)
    }

    func read(for date: Date) -> [NewsArticle]? {
        let fileURL = Self.cacheDir.appendingPathComponent(Self.filename(for: date))
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? Self.decoder.decode([NewsArticle].self, from: data)
    }

    // MARK: - Helpers

    private static func filename(for date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.locale = Locale(identifier: "en_US_POSIX")
        return "\(fmt.string(from: date)).json"
    }
}
