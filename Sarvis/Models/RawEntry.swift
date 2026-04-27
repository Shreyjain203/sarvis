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
    /// If a local notification was scheduled for this capture, its identifier.
    /// Stored on the raw so the classifier can carry it forward to the
    /// resulting `TodoItem`, and so swipe-delete on Entries can cancel the
    /// pending request before the raw is materialised.
    /// Defaults to nil so files written before this field was added decode cleanly.
    var notificationID: String?

    init(
        id: UUID,
        text: String,
        importance: Importance,
        isSensitive: Bool,
        suggestedType: InputType? = nil,
        dueAt: Date? = nil,
        capturedAt: Date,
        processed: Bool,
        processedAt: Date? = nil,
        notificationID: String? = nil
    ) {
        self.id = id
        self.text = text
        self.importance = importance
        self.isSensitive = isSensitive
        self.suggestedType = suggestedType
        self.dueAt = dueAt
        self.capturedAt = capturedAt
        self.processed = processed
        self.processedAt = processedAt
        self.notificationID = notificationID
    }

    // Custom Decodable so older `raw/<uuid>.json` files (written before
    // `notificationID` existed) still decode without error.
    enum CodingKeys: String, CodingKey {
        case id, text, importance, isSensitive, suggestedType, dueAt
        case capturedAt, processed, processedAt, notificationID
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(UUID.self, forKey: .id)
        self.text = try c.decode(String.self, forKey: .text)
        self.importance = try c.decode(Importance.self, forKey: .importance)
        self.isSensitive = try c.decode(Bool.self, forKey: .isSensitive)
        self.suggestedType = try c.decodeIfPresent(InputType.self, forKey: .suggestedType)
        self.dueAt = try c.decodeIfPresent(Date.self, forKey: .dueAt)
        self.capturedAt = try c.decode(Date.self, forKey: .capturedAt)
        self.processed = try c.decode(Bool.self, forKey: .processed)
        self.processedAt = try c.decodeIfPresent(Date.self, forKey: .processedAt)
        self.notificationID = try c.decodeIfPresent(String.self, forKey: .notificationID)
    }
}
