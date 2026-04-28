import Foundation

/// One Gmail message reduced to the metadata we keep on-device.
/// Privacy posture (Phase 2.2): we never store full bodies. Only the
/// subject, sender, and a short snippet (≤200 chars) come into the cache.
struct EmailItem: Identifiable, Codable, Hashable {
    /// Gmail message ID (from `users.messages.list`).
    let id: String
    /// Gmail thread ID — useful for grouping but currently informational.
    let threadID: String
    let subject: String
    let sender: String
    /// Truncated to ~200 chars by `GmailProvider`; never a full body.
    let snippet: String
    let receivedAt: Date
}

/// Abstraction so the email pipeline can be unit-tested or swapped to other
/// providers later. For Phase 2 we ship a single concrete implementation
/// (`GmailProvider`).
protocol EmailProvider {
    /// Fetches recent messages.
    /// - Parameters:
    ///   - limit: maximum number of messages to return (provider may cap further).
    ///   - since: a Gmail `q=` clause fragment ("newer_than:1d") or nil for the default ("newer_than:1d").
    func fetchRecent(limit: Int, since: String?) async throws -> [EmailItem]
}

enum EmailError: LocalizedError {
    case notConnected
    case badResponse(String)
    case decoding(Error)
    case authFailed(String)

    var errorDescription: String? {
        switch self {
        case .notConnected:        return "Gmail is not connected. Connect in Settings."
        case .badResponse(let m):  return "Gmail API error: \(m)"
        case .decoding(let e):     return "Could not decode Gmail response: \(e.localizedDescription)"
        case .authFailed(let m):   return "Gmail auth failed: \(m)"
        }
    }
}
