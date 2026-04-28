import SwiftUI
import WidgetKit

struct QuickCaptureView: View {
    let entry: QuickCaptureEntry

    private let captureURL = URL(string: "sarvis://capture")!

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Warm parchment background — mirrors WidgetTheme
                WidgetTheme.canvasBackground
                    .ignoresSafeArea()

                VStack(spacing: WidgetTheme.Spacing.md) {
                    // Header row
                    HStack(spacing: WidgetTheme.Spacing.xs) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(WidgetTheme.muted)
                        Text("Sarvis")
                            .font(.system(.footnote, design: .rounded).weight(.semibold))
                            .foregroundStyle(WidgetTheme.muted)
                        Spacer()
                    }

                    // Big faux text-field — wraps a Link so tap → deep-link
                    Link(destination: captureURL) {
                        fauxTextField
                            .frame(height: geo.size.height * 0.55)
                    }

                    // Wide Submit pill
                    Link(destination: captureURL) {
                        submitPill
                    }
                }
                .padding(WidgetTheme.Spacing.md)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    // MARK: - Subviews

    private var fauxTextField: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: WidgetTheme.Radius.textField, style: .continuous)
                .fill(WidgetTheme.inputBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: WidgetTheme.Radius.textField, style: .continuous)
                        .strokeBorder(WidgetTheme.hairline, lineWidth: 0.5)
                )

            VStack(alignment: .leading, spacing: WidgetTheme.Spacing.xs) {
                HStack(spacing: WidgetTheme.Spacing.xs) {
                    Image(systemName: "pencil")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(WidgetTheme.muted)
                    Text("What's on your mind?")
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(WidgetTheme.muted)
                }
                Spacer()
            }
            .padding(WidgetTheme.Spacing.md)
        }
        .frame(maxWidth: .infinity)
    }

    private var submitPill: some View {
        HStack(spacing: WidgetTheme.Spacing.xs) {
            Image(systemName: "arrow.up")
                .font(.system(size: 13, weight: .semibold))
            Text("Submit")
                .font(.system(.callout, design: .rounded).weight(.semibold))
        }
        .foregroundStyle(WidgetTheme.buttonForeground)
        .frame(maxWidth: .infinity)
        .padding(.vertical, WidgetTheme.Spacing.sm)
        .background {
            Capsule(style: .continuous)
                .fill(WidgetTheme.buttonBackground)
        }
    }
}

#if DEBUG
struct QuickCaptureView_Previews: PreviewProvider {
    static var previews: some View {
        QuickCaptureView(entry: QuickCaptureEntry(date: Date()))
            .previewContext(WidgetPreviewContext(family: .systemLarge))
            .previewDisplayName("Large")
    }
}
#endif
