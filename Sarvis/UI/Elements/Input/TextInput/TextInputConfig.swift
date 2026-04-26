import Foundation

/// Config knobs for `Input/TextInput`.
struct TextInputConfig {
    let placeholder: String
    let multiline: Bool
    let minHeight: Double

    init(spec: ElementSpec) {
        placeholder = spec.config["placeholder"]?.stringValue ?? "What's on your mind?"
        multiline   = spec.config["multiline"]?.boolValue    ?? true
        minHeight   = spec.config["minHeight"]?.doubleValue  ?? 140
    }
}
