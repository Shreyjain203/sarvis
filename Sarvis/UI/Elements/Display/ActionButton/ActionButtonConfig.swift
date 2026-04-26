import Foundation

/// Config knobs for `Display/ActionButton`.
struct ActionButtonConfig {
    let title: String
    /// String action ID passed to `DynamicScreen.onAction`.
    let action: String

    init(spec: ElementSpec) {
        title  = spec.config["title"]?.stringValue  ?? "Action"
        action = spec.config["action"]?.stringValue ?? ""
    }
}
