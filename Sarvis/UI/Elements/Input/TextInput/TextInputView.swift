import SwiftUI

/// A hero `TextEditor` matching the existing `InputView` card idiom.
/// Registers as `"Input/TextInput"`.
struct TextInputView: View {
    let spec: ElementSpec
    @ObservedObject var state: ScreenState

    @FocusState private var editorFocused: Bool

    private var cfg: TextInputConfig { TextInputConfig(spec: spec) }

    private var textBinding: Binding<String> {
        Binding(
            get: {
                guard let key = spec.bindingKey else { return "" }
                return state.values[key]?.stringValue ?? ""
            },
            set: { newVal in
                guard let key = spec.bindingKey else { return }
                state.values[key] = .string(newVal)
            }
        )
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            if textBinding.wrappedValue.isEmpty {
                Text(cfg.placeholder)
                    .font(.system(.title3, design: .serif))
                    .foregroundStyle(Theme.Palette.muted.opacity(0.7))
                    .padding(.top, 8)
                    .padding(.leading, 6)
                    .allowsHitTesting(false)
            }
            TextEditor(text: textBinding)
                .font(.system(.title3, design: .serif))
                .scrollContentBackground(.hidden)
                .focused($editorFocused)
                .frame(minHeight: cfg.minHeight, maxHeight: cfg.multiline ? 240 : CGFloat(cfg.minHeight))
                .tint(Theme.Palette.ink)
        }
        .themedCard(padding: Theme.Spacing.md, cornerRadius: Theme.Radius.hero)
    }
}
