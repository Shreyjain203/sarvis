import Foundation

/// A raw, unclassified capture that lands in `Documents/raw/<uuid>.json`.
/// The classifier pipeline reads these, sets `processed = true`, and routes
/// the content into the appropriate `Documents/processed/<type>.json` file.
struct RawEntry: Identifiable, Codable {
    let id: UUID
    var text: String
    var importance: Importance
    var isSensitive: Bool
    /// The type the user picked at capture time. May be overridden by the classifier.
    var suggestedType: InputType?
    var dueAt: Date?
    var capturedAt: Date
    var processed: Bool
    var processedAt: Date?
}
