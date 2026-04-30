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

    /// Removes the article with the given `id` (== `url`) from the cached list
    /// for `date` and rewrites the file atomically. Returns the new list, or
    /// `nil` if the file didn't exist or no matching article was found.
    @discardableResult
    func delete(articleID: String, for date: Date) -> [NewsArticle]? {
        guard var articles = read(for: date) else { return nil }
        let before = articles.count
        articles.removeAll { $0.id == articleID }
        guard articles.count != before else { return nil }
        do {
            try write(articles, for: date)
            return articles
        } catch {
            print("NewsCache delete error:", error)
            return nil
        }
    }

    // MARK: - Helpers

    private static func filename(for date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.locale = Locale(identifier: "en_US_POSIX")
        return "\(fmt.string(from: date)).json"
    }
}
