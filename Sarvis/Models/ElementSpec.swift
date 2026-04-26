import Foundation

/// Describes a single element on a dynamic screen.
struct ElementSpec: Identifiable, Codable {
    /// Unique within the screen.
    let id: String
    /// Matches a key registered in `ElementRegistry`.
    let type: String
    /// Element-specific configuration knobs.
    let config: [String: AnyCodableValue]
    /// Key path into the screen's `ScreenState.values` bag for two-way binding.
    let bindingKey: String?

    init(id: String,
         type: String,
         config: [String: AnyCodableValue] = [:],
         bindingKey: String? = nil) {
        self.id = id
        self.type = type
        self.config = config
        self.bindingKey = bindingKey
    }
}
