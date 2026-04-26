import SwiftUI

/// An inline `DatePicker` (`.graphical` style) that persists an ISO-8601
/// string (or `.null` when cleared) into the state bag.
/// Registers as `"Input/CalendarPicker"`.
struct CalendarPickerView: View {
    let spec: ElementSpec
    @ObservedObject var state: ScreenState

    private var cfg: CalendarPickerConfig { CalendarPickerConfig(spec: spec) }

    private static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private var dateBinding: Binding<Date> {
        Binding(
            get: {
                guard let key = spec.bindingKey,
                      let raw = state.values[key]?.stringValue,
                      let d = Self.iso8601.date(from: raw) else {
                    return Date().addingTimeInterval(3600)
                }
                return d
            },
            set: { newVal in
                guard let key = spec.bindingKey else { return }
                state.values[key] = .string(Self.iso8601.string(from: newVal))
            }
        )
    }

    private var components: DatePickerComponents {
        switch cfg.mode {
        case .date:        return .date
        case .time:        return .hourAndMinute
        case .dateAndTime: return [.date, .hourAndMinute]
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            sectionLabel("Due date")
            DatePicker("", selection: dateBinding, in: Date()..., displayedComponents: components)
                .datePickerStyle(.graphical)
                .tint(Theme.Palette.ink)
                .labelsHidden()

            if cfg.optional {
                Button {
                    Haptics.soft()
                    if let key = spec.bindingKey {
                        state.values[key] = .null
                    }
                } label: {
                    Text("Clear")
                        .font(Theme.Typography.meta())
                        .foregroundStyle(Theme.Palette.muted)
                        .underline()
                }
                .buttonStyle(.plain)
            }
        }
        .themedCard(padding: Theme.Spacing.md, cornerRadius: Theme.Radius.card)
    }

    @ViewBuilder
    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(Theme.Typography.meta())
            .tracking(1)
            .foregroundStyle(Theme.Palette.muted)
    }
}
