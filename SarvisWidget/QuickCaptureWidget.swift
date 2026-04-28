import WidgetKit
import SwiftUI

struct QuickCaptureWidget: Widget {
    let kind: String = "QuickCaptureWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickCaptureProvider()) { entry in
            QuickCaptureView(entry: entry)
        }
        .configurationDisplayName("Quick Capture")
        .description("Tap to open Sarvis and capture a thought.")
        .supportedFamilies([.systemLarge])
    }
}
