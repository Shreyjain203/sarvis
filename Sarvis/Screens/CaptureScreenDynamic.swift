import SwiftUI

// MARK: - Screen Definition

private let captureScreen = ScreenDefinition(
    id: "capture",
    title: "Capture",
    elements: [
        ElementSpec(
            id: "capture.text",
            type: "Input/TextInput",
            config: [
                "placeholder": .string("What's on your mind?"),
                "multiline": .bool(true),
                "minHeight": .double(140)
            ],
            bindingKey: "text"
        ),
        ElementSpec(
            id: "capture.type",
            type: "Input/TypeChip",
            config: [:],
            bindingKey: "inputType"
        ),
        ElementSpec(
            id: "capture.importance",
            type: "Input/ImportancePicker",
            config: [:],
            bindingKey: "importance"
        ),
        ElementSpec(
            id: "capture.sensitive",
            type: "Input/ToggleRow",
            config: [
                "label": .string("Sensitive"),
                "symbol": .string("lock.fill")
            ],
            bindingKey: "isSensitive"
        ),
        ElementSpec(
            id: "capture.dueAt",
            type: "Input/CalendarPicker",
            config: [
                "mode": .string("dateAndTime"),
                "optional": .bool(true)
            ],
            bindingKey: "dueAt"
        ),
        ElementSpec(
            id: "capture.aiAssist",
            type: "Display/ActionButton",
            config: [
                "title": .string("Process with LLM"),
                "action": .string("capture.aiAssist")
            ]
        ),
        ElementSpec(
            id: "capture.cleanupCurrent",
            type: "Display/ActionButton",
            config: [
                "title": .string("Clean up with Claude"),
                "action": .string("capture.cleanupCurrent")
            ]
        ),
        ElementSpec(
            id: "capture.save",
            type: "Display/ActionButton",
            config: [
                "title": .string("Save"),
                "action": .string("capture.save")
            ]
        )
    ]
)

// MARK: - CaptureScreenDynamic

/// A fully data-driven version of the capture screen, built on `DynamicScreen`.
/// Toggle into production use by replacing `InputView()` with
/// `CaptureScreenDynamic()` in `RootView.swift`.
///
/// NOTE: The `#if DYNAMIC_UI` flag below gates switching RootView to this
/// screen — the old `InputView` is left untouched as the fallback.
struct CaptureScreenDynamic: View {
    @EnvironmentObject var store: TodoStore
    @StateObject private var llm = LLMService()
    @ObservedObject private var classifier = ClassifierService.shared

    @State private var llmDraft = ""
    @State private var saveError: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.LayeredBackground()
                DynamicScreen(definition: captureScreen) { actionID, state in
                    Task { await handleAction(actionID, state: state) }
                }
                // LLM draft overlay — shown when Claude returns a suggestion
                .overlay(alignment: .bottom) {
                    if !llmDraft.isEmpty {
                        llmDraftBanner
                            .padding(.horizontal, Theme.Spacing.lg)
                            .padding(.bottom, 112)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: llmDraft.isEmpty)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Haptics.light()
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundStyle(Theme.Palette.muted)
                    }
                }
            }
        }
    }

    // MARK: Action dispatch

    @MainActor
    private func handleAction(_ actionID: String, state: ScreenState) async {
        switch actionID {
        case "capture.save":
            await performSave(state: state)
        case "capture.aiAssist":
            await performClassify()
        case "capture.cleanupCurrent":
            await performAIAssist(state: state)
        default:
            break
        }
    }

    private func performSave(state: ScreenState) async {
        let rawText = state.string(for: "text") ?? ""
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let inputType: InputType = {
            if let raw = state.string(for: "inputType"),
               let t = InputType(rawValue: raw) { return t }
            return .task
        }()
        let importance: Importance = {
            if let i = state.values["importance"]?.intValue,
               let imp = Importance(rawValue: i) { return imp }
            return .medium
        }()
        let isSensitive = state.bool(for: "isSensitive") ?? false

        // Resolve dueAt from ISO-8601 string if present
        let dueDate: Date? = {
            guard let raw = state.string(for: "dueAt"),
                  raw != "null" else { return nil }
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime]
            return f.date(from: raw)
        }()

        // Schedule notification if dueDate is set
        var notificationID: String?
        if let dueDate {
            let temp = TodoItem(
                text: text,
                importance: importance,
                isSensitive: isSensitive,
                type: inputType,
                dueAt: dueDate
            )
            do {
                notificationID = try await NotificationService.shared.schedule(temp, at: dueDate)
            } catch {
                saveError = "Couldn't schedule notification: \(error.localizedDescription)"
                return
            }
        }

        var saved = store.capture(
            text: text,
            type: inputType,
            importance: importance,
            isSensitive: isSensitive,
            dueAt: dueDate
        )

        if let nid = notificationID {
            saved.notificationID = nid
            store.update(saved)
        }

        Haptics.success()
        ToastCenter.shared.show("Saved")
        state.reset()
        llmDraft = ""
        saveError = nil
    }

    private func performClassify() async {
        guard !classifier.isRunning else { return }
        do {
            let report = try await ClassifierService.shared.classifyUnprocessed()
            ToastCenter.shared.show("Processed \(report.itemsAdded) item\(report.itemsAdded == 1 ? "" : "s")")
        } catch {
            ToastCenter.shared.show("Process failed")
        }
    }

    private func performAIAssist(state: ScreenState) async {
        let text = (state.string(for: "text") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !llm.isSending else { return }
        let result = await llm.ask(
            systemPrompt: PromptLibrary.body(
                for: "capture_cleanup",
                fallback: "Rewrite the user's note as one short, clear todo line. Keep their intent. No preamble."
            ),
            prompt: text
        )
        if let result {
            llmDraft = result.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    // MARK: LLM draft banner

    private var llmDraftBanner: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("Claude suggests")
                .font(Theme.Typography.meta())
                .foregroundStyle(Theme.Palette.muted)
                .textCase(.uppercase)
                .tracking(0.5)
            Text(llmDraft)
                .font(.system(.callout, design: .serif))
                .foregroundStyle(Theme.Palette.inkSoft)
            // "Use this" injects the draft back into the state bag via a fresh
            // DynamicScreen state — we can't access it here, so we use a
            // notification-style approach: store in a shared ephemeral place.
            // For now the user can copy/type it; full integration is a next step.
            Button {
                Haptics.soft()
                llmDraft = ""
            } label: {
                Text("Dismiss")
                    .font(Theme.Typography.meta())
                    .foregroundStyle(Theme.Palette.muted)
                    .underline()
            }
            .buttonStyle(.plain)
        }
        .themedCard(padding: Theme.Spacing.md, cornerRadius: Theme.Radius.card)
    }
}

#Preview {
    CaptureScreenDynamic().environmentObject(TodoStore.shared)
}
