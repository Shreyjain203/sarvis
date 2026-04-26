import Foundation

protocol NewsProvider {
    func fetchTopHeadlines(country: String, limit: Int) async throws -> [NewsArticle]
}

enum NewsError: Error {
    case noAPIKey
    case badResponse
    case decoding(Error)
}
