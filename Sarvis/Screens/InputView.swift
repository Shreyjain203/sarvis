import SwiftUI

struct InputView: View {
    @EnvironmentObject var store: TodoStore
    @ObservedObject private var classifier = ClassifierService.shared

    @State private var text = ""
    @State private var importance: Importance = .medium
    @State private var inputType: InputType = .task
    @State private var isSensitive = false
    @State private var enableNotification = false
    @State private var dueAt: Date = Date()
    @State private var showSettings = false
    @State private var saveError: String?

    @Namespace private var importanceNS
    @Namespace private var inputTypeNS
    @FocusState private var editorFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.LayeredBackground()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                        header
                        editorCard
                        importanceRow
                        inputTypeRow
                        sensitiveAndDate
                        saveButton
                        statusFooter
                        // Bottom space for the floating tab bar
                        Color.clear.frame(height: 96)
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.top, Theme.Spacing.md)
                }
                .scrollDismissesKeyboard(.immediately)
                .dismissKeyboardToolbar()
            }
            // Tap on any non-interactive area dismisses the keyboard.
            // Buttons / TextEditor consume their own taps, so this only fires on background.
            .onTapGesture {
                if editorFocused { editorFocused = false }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        Haptics.light()
                        Task { await runClassifier() }
                    } label: {
                        if classifier.isRunning {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 16, weight: .regular))
                                .foregroundStyle(Theme.Palette.muted)
                        }
                    }
                    .disabled(classifier.isRunning)

                    Button {
                        Haptics.light()
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundStyle(Theme.Palette.muted)
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
    }

    // MARK: Header
    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Capture")
                .font(Theme.Typography.title())
                .foregroundStyle(Theme.Palette.ink)
            Text("A quiet place for the things you don't want to forget.")
                .font(Theme.Typography.meta())
                .foregroundStyle(Theme.Palette.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Hero text editor
    private var editorCard: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text("What's on your mind?")
                    .font(.system(.title3, design: .serif))
                    .foregroundStyle(Theme.Palette.muted.opacity(0.7))
                    .padding(.top, 8)
                    .padding(.leading, 6)
                    .allowsHitTesting(false)
            }
            TextEditor(text: $text)
                .font(.system(.title3, design: .serif))
                .scrollContentBackground(.hidden)
                .focused($editorFocused)
                .frame(minHeight: 140, maxHeight: 240)
                .tint(Theme.Palette.ink)
        }
        .themedCard(padding: Theme.Spacing.md, cornerRadius: Theme.Radius.hero)
    }

    // MARK: Importance chips
    private var importanceRow: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            label("Importance")
            HStack(spacing: Theme.Spacing.xs) {
                ForEach(Importance.allCases) { imp in
                    ImportanceChip(
                        importance: imp,
                        isSelected: importance == imp,
                        ns: importanceNS
                    ) {
                        Haptics.soft()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            importance = imp
                        }
                    }
                }
            }
        }
    }

    // MARK: InputType chips
    private var inputTypeRow: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            label("Type")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.xs) {
                    ForEach(InputType.allCases) { type in
                        InputTypeChip(
                            inputType: type,
                            isSelected: inputType == type,
                            ns: inputTypeNS
                        ) {
                            Haptics.soft()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                inputType = type
                                // Auto-sync sensitive toggle when user picks the sensitive type.
                                if type == .sensitive { isSensitive = true }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: Sensitive + date
    private var sensitiveAndDate: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.sm) {
                LockPill(isOn: $isSensitive)
                Spacer()
                NotificationPill(isOn: $enableNotification)
            }

            if enableNotification {
                HStack {
                    Image(systemName: "bell")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.Palette.muted)
                    Text("Remind me")
                        .font(Theme.Typography.body())
                        .foregroundStyle(Theme.Palette.inkSoft)
                    Spacer()
                    DatePicker("", selection: $dueAt, in: Date()...)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                }
                .themedCard(padding: Theme.Spacing.sm + 4,
                            cornerRadius: Theme.Radius.card)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: enableNotification)
    }

    // MARK: Save button
    private var saveButton: some View {
        Button {
            Task { await save() }
        } label: {
            Text("Save")
                .font(Theme.Typography.bodyEmphasis())
                .foregroundStyle(Color(uiColor: .systemBackground))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background {
                    RoundedRectangle(cornerRadius: Theme.Radius.chip, style: .continuous)
                        .fill(Theme.Palette.ink)
                }
                .opacity(text.trimmingCharacters(in: .whitespaces).isEmpty ? 0.35 : 1)
        }
        .buttonStyle(.plain)
        .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    private var statusFooter: some View {
        VStack(spacing: 4) {
            if let err = saveError {
                Text(err)
                    .font(Theme.Typography.meta())
                    .foregroundStyle(.red.opacity(0.85))
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func label(_ s: String) -> some View {
        Text(s.uppercased())
            .font(Theme.Typography.meta())
            .tracking(1)
            .foregroundStyle(Theme.Palette.muted)
    }

    // MARK: Logic
    private func runClassifier() async {
        guard !classifier.isRunning else { return }
        do {
            let report = try await ClassifierService.shared.classifyUnprocessed()
            if report.itemsAdded == 0 {
                // Happy path with zero items can mean "nothing to do" OR a
                // silent LLM/parse hiccup that resolved to an empty `items`
                // array. Surface the underlying error if there is one.
                if let llmErr = ClassifierService.shared.lastLLMError, !llmErr.isEmpty {
                    ToastCenter.shared.show(Self.truncated(llmErr))
                } else {
                    ToastCenter.shared.show("Nothing to process")
                }
            } else {
                ToastCenter.shared.show("Processed \(report.itemsAdded) item\(report.itemsAdded == 1 ? "" : "s")")
            }
        } catch {
            ToastCenter.shared.show(Self.truncated(error.localizedDescription))
        }
    }

    private static func truncated(_ s: String, max: Int = 140) -> String {
        if s.count <= max { return s }
        return String(s.prefix(max - 1)) + "…"
    }

    private func save() async {
        let dueDate: Date? = enableNotification ? dueAt : nil
        var notificationID: String?

        if enableNotification {
            // Build a temporary item to schedule the notification.
            let temp = TodoItem(
                text: text.trimmingCharacters(in: .whitespacesAndNewlines),
                importance: importance,
                isSensitive: isSensitive,
                type: inputType,
                dueAt: dueDate
            )
            do {
                notificationID = try await NotificationService.shared.schedule(temp, at: dueAt)
            } catch {
                saveError = "Couldn't schedule notification: \(error.localizedDescription)"
                return
            }
        }

        // Persist as a raw entry. The returned in-memory TodoItem shares the
        // raw's id; nothing is written to processed/<type>.json until the
        // classifier runs.
        let saved = store.capture(
            text: text.trimmingCharacters(in: .whitespacesAndNewlines),
            type: inputType,
            importance: importance,
            isSensitive: isSensitive,
            dueAt: dueDate
        )

        // If a notification was scheduled, store its id on the raw so:
        //  1) swipe-delete on Entries can cancel it,
        //  2) the classifier can carry it onto the materialised TodoItem.
        if let nid = notificationID {
            await MainActor.run {
                RawStore.shared.setNotificationID(for: saved.id, nid)
            }
        }

        Haptics.success()
        ToastCenter.shared.show("Saved")

        text = ""
        importance = .medium
        inputType = .task
        isSensitive = false
        enableNotification = false
        dueAt = Date()
        saveError = nil
    }
}

// MARK: - Importance chip
private struct ImportanceChip: View {
    let importance: Importance
    let isSelected: Bool
    var ns: Namespace.ID
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: importance.symbol)
                    .font(.system(size: 11, weight: .medium))
                Text(importance.label)
                    .font(Theme.Typography.chip())
            }
            .foregroundStyle(isSelected ? Color(uiColor: .systemBackground) : Theme.Palette.inkSoft)
            .padding(.horizontal, Theme.Spacing.sm + 2)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: Theme.Radius.chip, style: .continuous)
                        .fill(Theme.Palette.ink)
                        .matchedGeometryEffect(id: "importanceIndicator", in: ns)
                } else {
                    RoundedRectangle(cornerRadius: Theme.Radius.chip, style: .continuous)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: Theme.Radius.chip, style: .continuous)
                        .strokeBorder(Theme.Palette.hairline, lineWidth: 0.5)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.chip))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - InputType chip
private struct InputTypeChip: View {
    let inputType: InputType
    let isSelected: Bool
    var ns: Namespace.ID
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: inputType.symbol)
                    .font(.system(size: 11, weight: .medium))
                Text(inputType.label)
                    .font(Theme.Typography.chip())
            }
            .foregroundStyle(isSelected ? Color(uiColor: .systemBackground) : Theme.Palette.inkSoft)
            .padding(.horizontal, Theme.Spacing.sm + 2)
            .padding(.vertical, 8)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: Theme.Radius.chip, style: .continuous)
                        .fill(Theme.Palette.ink)
                        .matchedGeometryEffect(id: "inputTypeIndicator", in: ns)
                } else {
                    RoundedRectangle(cornerRadius: Theme.Radius.chip, style: .continuous)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: Theme.Radius.chip, style: .continuous)
                        .strokeBorder(Theme.Palette.hairline, lineWidth: 0.5)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.chip))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Lock pill
private struct LockPill: View {
    @Binding var isOn: Bool

    var body: some View {
        Button {
            Haptics.soft()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                isOn.toggle()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isOn ? "lock.fill" : "lock.open")
                    .font(.system(size: 12, weight: .medium))
                Text(isOn ? "Sensitive" : "Private?")
                    .font(Theme.Typography.chip())
            }
            .foregroundStyle(isOn ? Color.red.opacity(0.9) : Theme.Palette.muted)
            .padding(.horizontal, Theme.Spacing.sm + 2)
            .padding(.vertical, 8)
            .background {
                Capsule(style: .continuous)
                    .fill(isOn ? Theme.Palette.sensitiveTint : Color.clear)
                Capsule(style: .continuous)
                    .fill(.ultraThinMaterial)
                    .opacity(isOn ? 0 : 1)
            }
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(isOn ? Color.red.opacity(0.3) : Theme.Palette.hairline,
                                  lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Notification pill
private struct NotificationPill: View {
    @Binding var isOn: Bool

    var body: some View {
        Button {
            Haptics.soft()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                isOn.toggle()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isOn ? "bell.fill" : "bell.slash")
                    .font(.system(size: 12, weight: .medium))
                Text(isOn ? "Remind" : "No reminder")
                    .font(Theme.Typography.chip())
            }
            .foregroundStyle(isOn ? Theme.Palette.ink : Theme.Palette.muted)
            .padding(.horizontal, Theme.Spacing.sm + 2)
            .padding(.vertical, 8)
            .background {
                Capsule(style: .continuous).fill(.ultraThinMaterial)
            }
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(Theme.Palette.hairline, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    InputView().environmentObject(TodoStore.shared)
}
