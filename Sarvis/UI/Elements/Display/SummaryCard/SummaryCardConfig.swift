import Foundation

/// Config knobs for `Display/SummaryCard`.
struct SummaryCardConfig {
    let title: String?

    init(spec: ElementSpec) {
        title = spec.config["title"]?.stringValue
    }
}
