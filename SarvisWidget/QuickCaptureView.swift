import SwiftUI
import WidgetKit

struct QuickCaptureView: View {
    let entry: QuickCaptureEntry
    @Environment(\.widgetFamily) private var family

    private let captureURL = URL(string: "sarvis://capture")!

    var body: some View {
        Link(destination: captureURL) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .systemSmall:
            smallLayout
        default:
            mediumLayout
        }
    }

    // MARK: Small (2x2)
    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: WidgetTheme.Spacing.sm) {
            Label("Sarvis", systemImage: "square.and.pencil")
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .foregroundStyle(WidgetTheme.ink)

            Spacer()

            // Faux text-box pill
            fauxPill
                .frame(maxWidth: .infinity)

            Spacer()

            // Submit pill button
            submitButton
                .frame(maxWidth: .infinity)
        }
        .padding(WidgetTheme.Spacing.md)
    }

    // MARK: Medium (4x2)
    private var mediumLayout: some View {
        HStack(spacing: WidgetTheme.Spacing.md) {
            VStack(alignment: .leading, spacing: WidgetTheme.Spacing.xs) {
                Label("Quick Capture", systemImage: "square.and.pencil")
                    .font(.system(.footnote, design: .rounded).weight(.semibold))
                    .foregroundStyle(WidgetTheme.ink)
                Text("Jot a note in one tap.")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(WidgetTheme.muted)
            }

            Spacer()

            VStack(spacing: WidgetTheme.Spacing.xs) {
                fauxPill
                    .frame(maxWidth: 200)
                submitButton
                    .frame(maxWidth: 200)
            }
        }
        .padding(WidgetTheme.Spacing.md)
    }

    // MARK: Subviews

    private var fauxPill: some View {
        HStack(spacing: WidgetTheme.Spacing.xs) {
            Image(systemName: "pencil")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(WidgetTheme.muted)
            Text("Capture a note…")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(WidgetTheme.muted)
            Spacer()
        }
        .padding(.horizontal, WidgetTheme.Spacing.sm)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: WidgetTheme.Radius.pill, style: .continuous)
                .fill(WidgetTheme.inputBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: WidgetTheme.Radius.pill, style: .continuous)
                        .strokeBorder(WidgetTheme.hairline, lineWidth: 0.5)
                )
        }
    }

    private var submitButton: some View {
        HStack(spacing: 4) {
            Image(systemName: "arrow.up")
                .font(.system(size: 10, weight: .semibold))
            Text("Submit")
                .font(.system(.caption, design: .rounded).weight(.semibold))
        }
        .foregroundStyle(WidgetTheme.buttonForeground)
        .padding(.horizontal, WidgetTheme.Spacing.sm)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: WidgetTheme.Radius.pill, style: .continuous)
                .fill(WidgetTheme.buttonBackground)
        }
    }
}

#if DEBUG
struct QuickCaptureView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            QuickCaptureView(entry: QuickCaptureEntry(date: Date()))
                .previewContext(WidgetPreviewContext(family: .systemSmall))
                .previewDisplayName("Small")
            QuickCaptureView(entry: QuickCaptureEntry(date: Date()))
                .previewContext(WidgetPreviewContext(family: .systemMedium))
                .previewDisplayName("Medium")
        }
    }
}
#endif
