import Foundation

@MainActor
final class NewsService: ObservableObject {
    static let shared = NewsService()

    @Published private(set) var lastError: Error?

    private let provider: NewsProvider
    private let cache: NewsCache

    init(provider: NewsProvider = GNewsProvider(), cache: NewsCache = NewsCache()) {
        self.provider = provider
        self.cache = cache
    }

    /// Fetches top headlines, writes them to the cache for today, and returns the articles.
    @discardableResult
    func refreshToday(country: String = "us", limit: Int = 10) async throws -> [NewsArticle] {
        do {
            let articles = try await provider.fetchTopHeadlines(country: country, limit: limit)
            try cache.write(articles, for: Date())
            lastError = nil
            return articles
        } catch {
            lastError = error
            throw error
        }
    }

    /// Returns cached articles for today without hitting the network.
    func articlesForToday() -> [NewsArticle]? {
        cache.read(for: Date())
    }
}
