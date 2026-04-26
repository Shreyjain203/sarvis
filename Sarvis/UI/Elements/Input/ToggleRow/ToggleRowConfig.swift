import Foundation

/// Config knobs for `Input/ToggleRow`.
struct ToggleRowConfig {
    let label: String
    let symbol: String

    init(spec: ElementSpec) {
        label  = spec.config["label"]?.stringValue  ?? "Toggle"
        symbol = spec.config["symbol"]?.stringValue ?? "switch.2"
    }
}
