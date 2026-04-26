import WidgetKit
import SwiftUI

struct QuickCaptureWidget: Widget {
    let kind: String = "QuickCaptureWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickCaptureProvider()) { entry in
            QuickCaptureView(entry: entry)
        }
        .configurationDisplayName("Quick Capture")
        .description("Jot a note in one tap.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
