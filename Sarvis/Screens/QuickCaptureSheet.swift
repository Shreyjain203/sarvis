import SwiftUI

/// Modal sheet opened when the user taps the Quick Capture widget.
/// A focused text field lets them type a note immediately; Submit persists
/// it via `TodoStore.shared.capture(...)` and shows a toast.
struct QuickCaptureSheet: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var fieldFocused: Bool
    @State private var text = ""

    private var isBlank: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.LayeredBackground()

                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Quick capture")
                            .font(Theme.Typography.title())
                            .foregroundStyle(Theme.Palette.ink)
                        Text("Type a note and tap Submit.")
                            .font(Theme.Typography.meta())
                            .foregroundStyle(Theme.Palette.muted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Input card
                    ZStack(alignment: .topLeading) {
                        if text.isEmpty {
                            Text("What's on your mind?")
                                .font(.system(.title3, design: .serif))
                                .foregroundStyle(Theme.Palette.muted.opacity(0.7))
                                .padding(.top, 8)
                                .padding(.leading, 6)
                                .allowsHitTesting(false)
                        }
                        TextField("", text: $text, axis: .vertical)
                            .font(.system(.title3, design: .serif))
                            .lineLimit(4...10)
                            .focused($fieldFocused)
                            .tint(Theme.Palette.ink)
                    }
                    .themedCard(padding: Theme.Spacing.md, cornerRadius: Theme.Radius.hero)

                    // Submit button
                    Button {
                        submit()
                    } label: {
                        Text("Submit")
                            .font(Theme.Typography.bodyEmphasis())
                            .foregroundStyle(Color(uiColor: .systemBackground))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background {
                                RoundedRectangle(cornerRadius: Theme.Radius.chip, style: .continuous)
                                    .fill(Theme.Palette.ink)
                            }
                            .opacity(isBlank ? 0.35 : 1)
                    }
                    .buttonStyle(.plain)
                    .disabled(isBlank)

                    Spacer()
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.md)
            }
            .dismissKeyboardToolbar()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(Theme.Typography.body())
                    .foregroundStyle(Theme.Palette.muted)
                }
            }
        }
        .onAppear {
            // Small delay so the sheet animation finishes before keyboard appears.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                fieldFocused = true
            }
        }
    }

    // MARK: - Logic

    private func submit() {
        guard !isBlank else { return }
        TodoStore.shared.capture(
            text: text.trimmingCharacters(in: .whitespacesAndNewlines),
            type: .note,
            importance: .medium,
            isSensitive: false,
            dueAt: nil
        )
        ToastCenter.shared.show("Captured")
        dismiss()
    }
}

#Preview {
    QuickCaptureSheet()
        .environmentObject(TodoStore.shared)
}
