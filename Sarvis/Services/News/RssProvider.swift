import Foundation

/// Google News RSS provider. Replaces `GNewsProvider` (deprecated v0.2.0).
/// Uses `Foundation.XMLParser` — no third-party dependencies.
struct RssProvider: NewsProvider {

    /// UserDefaults key for the user-configured news topic.
    static let topicDefaultsKey = "sarvis_news_topic"
    /// Fallback topic when nothing has been stored yet.
    static let defaultTopic = "top news"

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchTopHeadlines(country: String, limit: Int) async throws -> [NewsArticle] {
        let topic = UserDefaults.standard.string(forKey: RssProvider.topicDefaultsKey)
            ?? RssProvider.defaultTopic

        guard var components = URLComponents(string: "https://news.google.com/rss/search") else {
            throw NewsError.badResponse
        }
        components.queryItems = [
            URLQueryItem(name: "q",    value: topic),
            URLQueryItem(name: "hl",   value: "en-US"),
            URLQueryItem(name: "gl",   value: country.uppercased()),
            URLQueryItem(name: "ceid", value: "\(country.uppercased()):en")
        ]

        guard let url = components.url else {
            throw NewsError.badResponse
        }

        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw NewsError.badResponse
        }

        let parser = RssFeedParser()
        return try parser.parse(data: data, limit: limit)
    }
}

// MARK: - RSS XML parser

private final class RssFeedParser: NSObject, XMLParserDelegate {

    private var articles: [NewsArticle] = []
    private var currentElement: String = ""
    private var currentTitle: String = ""
    private var currentLink: String = ""
    private var currentDescription: String = ""
    private var currentPubDate: String = ""
    private var currentSource: String = ""
    private var insideItem = false
    private var buffer = ""

    private var parseError: Error?

    func parse(data: Data, limit: Int) throws -> [NewsArticle] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        if let error = parseError { throw error }
        return Array(articles.prefix(limit))
    }

    // MARK: XMLParserDelegate

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        currentElement = elementName
        buffer = ""
        if elementName == "item" {
            insideItem = true
            currentTitle = ""
            currentLink = ""
            currentDescription = ""
            currentPubDate = ""
            currentSource = ""
        }
        // <source url="..."> attribute on an item
        if insideItem && elementName == "source" {
            currentSource = attributeDict["url"] ?? ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        buffer += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        guard insideItem else { return }
        let text = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
        switch elementName {
        case "title":       currentTitle       = text
        case "link":        currentLink        = text
        case "description": currentDescription = text
        case "pubDate":     currentPubDate     = text
        case "source":
            // text content of <source> is the human-readable source name
            if !text.isEmpty { currentSource = text }
        case "item":
            insideItem = false
            let pubDate = Self.parseDate(currentPubDate) ?? Date.distantPast
            // Google News RSS puts the source name in the title as " - Source" suffix.
            // Extract it if present so `source` is populated cleanly.
            let (cleanTitle, extractedSource) = Self.splitTitleSource(currentTitle)
            let sourceName: String? = extractedSource ?? (currentSource.isEmpty ? nil : currentSource)
            let article = NewsArticle(
                title: cleanTitle,
                description: currentDescription.isEmpty ? nil : currentDescription,
                url: currentLink,
                source: sourceName,
                publishedAt: pubDate
            )
            articles.append(article)
        default: break
        }
        buffer = ""
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        self.parseError = parseError
    }

    // MARK: Helpers

    /// Parses RFC 2822 pub-dates ("Fri, 25 Apr 2025 10:00:00 GMT").
    private static func parseDate(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        return formatter.date(from: string)
    }

    /// Google News RSS titles look like "Article headline - Source Name".
    /// Splits on the last " - " separator.
    private static func splitTitleSource(_ raw: String) -> (title: String, source: String?) {
        guard let range = raw.range(of: " - ", options: .backwards) else {
            return (raw, nil)
        }
        let title  = String(raw[raw.startIndex..<range.lowerBound])
        let source = String(raw[range.upperBound...])
        return (title.isEmpty ? raw : title, source.isEmpty ? nil : source)
    }
}
