import Foundation

/// A data-driven description of a screen: a title plus an ordered list of
/// element specifications. Load from code or decode from JSON (next step).
struct ScreenDefinition: Codable {
    let id: String
    let title: String
    let elements: [ElementSpec]

    init(id: String, title: String, elements: [ElementSpec]) {
        self.id = id
        self.title = title
        self.elements = elements
    }
}
