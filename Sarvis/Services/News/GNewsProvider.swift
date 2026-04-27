// DEPRECATED as of v0.2.0 — replaced by RssProvider. Kept for reference; delete once RSS is stable.
import Foundation

struct GNewsProvider: NewsProvider {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchTopHeadlines(country: String, limit: Int) async throws -> [NewsArticle] {
        guard let apiKey = KeychainService.read("gnews_api_key"), !apiKey.isEmpty else {
            throw NewsError.noAPIKey
        }

        var components = URLComponents(string: "https://gnews.io/api/v4/top-headlines")!
        components.queryItems = [
            URLQueryItem(name: "lang", value: "en"),
            URLQueryItem(name: "country", value: country),
            URLQueryItem(name: "max", value: "\(limit)"),
            URLQueryItem(name: "apikey", value: apiKey)
        ]

        let request = URLRequest(url: components.url!)
        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw NewsError.badResponse
        }

        do {
            let decoded = try JSONDecoder.gnews.decode(GNewsResponse.self, from: data)
            return decoded.articles.map { $0.toNewsArticle() }
        } catch {
            throw NewsError.decoding(error)
        }
    }
}

// MARK: - GNews response shapes

private struct GNewsResponse: Decodable {
    let articles: [GNewsArticle]
}

private struct GNewsArticle: Decodable {
    let title: String
    let description: String?
    let url: String
    let source: GNewsSource?
    let publishedAt: String

    func toNewsArticle() -> NewsArticle {
        let date = ISO8601DateFormatter().date(from: publishedAt) ?? Date.distantPast
        return NewsArticle(
            title: title,
            description: description,
            url: url,
            source: source?.name,
            publishedAt: date
        )
    }
}

private struct GNewsSource: Decodable {
    let name: String?
}

// MARK: - Decoder helper

private extension JSONDecoder {
    static let gnews: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .useDefaultKeys
        return d
    }()
}
