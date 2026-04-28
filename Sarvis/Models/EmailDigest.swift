import Foundation

/// Result of one round of LLM email classification.
///
/// The classifier reads `[EmailItem]` and writes back which IDs landed in
/// each bucket, plus any extracted action items. We keep the buckets as
/// expanded `[EmailItem]` (resolved from the IDs) rather than ID lists so
/// downstream UI doesn't have to re-join. Persisted at
/// `Documents/processed/email/<YYYY-MM-DD>.json`.
struct EmailDigest: Codable {
    let date: Date
    let important: [EmailItem]
    let fyi: [EmailItem]
    let promo: [EmailItem]
    let actions: [EmailAction]
}

/// One action item extracted from an email by the classifier.
struct EmailAction: Codable, Hashable, Identifiable {
    var id: String { sourceMessageID + ":" + text }
    let text: String
    let sourceMessageID: String
    let dueAt: Date?
}
