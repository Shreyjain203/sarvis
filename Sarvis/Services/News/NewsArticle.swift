import Foundation

struct NewsArticle: Identifiable, Codable, Hashable {
    var id: String { url }
    let title: String
    let description: String?
    let url: String
    let source: String?
    let publishedAt: Date
}
