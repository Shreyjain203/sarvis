import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage(LLMService.modelDefaultsKey) private var model: String = "claude-opus-4-7"
    @AppStorage(LLMService.maxTokensDefaultsKey) private var maxTokens: Int = 1024

    @State private var apiKey: String = ""
    @State private var newsTopic: String = ""

    @StateObject private var googleAuth = GoogleAuth.shared
    @State private var isAuthorizing = false
    @State private var gmailError: String? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.LayeredBackground()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                        header
                        apiKeyCard
                        newsTopicCard
                        gmailCard
                        modelCard
                        actionsRow
                        debugCard
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.top, Theme.Spacing.md)
                    .padding(.bottom, Theme.Spacing.xl)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .dismissKeyboardToolbar()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        Haptics.light()
                        dismiss()
                    } label: {
                        Text("Done")
                            .font(Theme.Typography.bodyEmphasis())
                            .foregroundStyle(Theme.Palette.ink)
                    }
                }
            }
            .onAppear {
                apiKey = KeychainService.read(LLMService.apiKeyAccount) ?? ""
                newsTopic = UserDefaults.standard.string(forKey: RssProvider.topicDefaultsKey)
                    ?? RssProvider.defaultTopic
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Settings")
                .font(Theme.Typography.title())
                .foregroundStyle(Theme.Palette.ink)
            Text("Quiet preferences for your assistant.")
                .font(Theme.Typography.meta())
                .foregroundStyle(Theme.Palette.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var apiKeyCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            sectionLabel("Anthropic API key")
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                SecureField("sk-ant-…", text: $apiKey)
                    .font(.system(.body, design: .monospaced))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(.vertical, 10)
                Divider().background(Theme.Palette.hairline)
                Text("Stored in iOS Keychain. Get a key at console.anthropic.com.")
                    .font(Theme.Typography.meta())
                    .foregroundStyle(Theme.Palette.muted)
            }
            .themedCard(padding: Theme.Spacing.md, cornerRadius: Theme.Radius.card)
        }
    }

    private var newsTopicCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            sectionLabel("News topic")
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                TextField(RssProvider.defaultTopic, text: $newsTopic)
                    .font(Theme.Typography.body())
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .onSubmit { saveNewsTopic() }
                    .padding(.vertical, 10)
                Divider().background(Theme.Palette.hairline)
                HStack(spacing: Theme.Spacing.sm) {
                    Button {
                        saveNewsTopic()
                    } label: {
                        Text("Save")
                            .font(Theme.Typography.bodyEmphasis())
                            .foregroundStyle(Theme.Palette.ink)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Button {
                        Haptics.light()
                        UserDefaults.standard.removeObject(forKey: RssProvider.topicDefaultsKey)
                        newsTopic = RssProvider.defaultTopic
                        ToastCenter.shared.show("Reset to default topic")
                    } label: {
                        Text("Reset")
                            .font(Theme.Typography.body())
                            .foregroundStyle(Theme.Palette.muted)
                    }
                    .buttonStyle(.plain)
                }
                Divider().background(Theme.Palette.hairline)
                Text("Controls the Google News RSS search query used by the morning briefing.")
                    .font(Theme.Typography.meta())
                    .foregroundStyle(Theme.Palette.muted)
            }
            .themedCard(padding: Theme.Spacing.md, cornerRadius: Theme.Radius.card)
        }
    }

    private var gmailCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            sectionLabel("Gmail")
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                if googleAuth.isConnected {
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "checkmark.seal")
                            .font(.system(size: 14, weight: .light))
                            .foregroundStyle(Theme.Palette.muted)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Connected")
                                .font(Theme.Typography.bodyEmphasis())
                                .foregroundStyle(Theme.Palette.ink)
                            if let email = googleAuth.email {
                                Text(email)
                                    .font(Theme.Typography.meta())
                                    .foregroundStyle(Theme.Palette.muted)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 6)

                    Divider().background(Theme.Palette.hairline)

                    Button {
                        Haptics.light()
                        googleAuth.disconnect()
                        EmailCache().clearAll()
                        ToastCenter.shared.show("Gmail disconnected")
                    } label: {
                        Text("Disconnect")
                            .font(Theme.Typography.body())
                            .foregroundStyle(.red.opacity(0.85))
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 6)
                } else {
                    Button {
                        connectGmail()
                    } label: {
                        HStack(spacing: Theme.Spacing.sm) {
                            Image(systemName: "envelope")
                                .font(.system(size: 14, weight: .light))
                                .foregroundStyle(Theme.Palette.muted)
                            Text(isAuthorizing ? "Connecting…" : "Connect Gmail")
                                .font(Theme.Typography.bodyEmphasis())
                                .foregroundStyle(Theme.Palette.ink)
                            Spacer(minLength: 0)
                            if isAuthorizing {
                                ProgressView()
                                    .scaleEffect(0.7)
                            } else {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Theme.Palette.muted)
                            }
                        }
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(isAuthorizing)

                    if let err = gmailError {
                        Divider().background(Theme.Palette.hairline)
                        Text(err)
                            .font(Theme.Typography.meta())
                            .foregroundStyle(Theme.Palette.sensitiveAccent)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 4)
                    }
                }

                Divider().background(Theme.Palette.hairline)
                Text("Read-only access (gmail.readonly). Subjects, sender, and 200-char snippets only — no full bodies. Refresh token in Keychain.")
                    .font(Theme.Typography.meta())
                    .foregroundStyle(Theme.Palette.muted)
            }
            .themedCard(padding: Theme.Spacing.md, cornerRadius: Theme.Radius.card)
        }
    }

    private func connectGmail() {
        gmailError = nil
        isAuthorizing = true
        Task { @MainActor in
            do {
                try await googleAuth.authorize()
                Haptics.success()
                ToastCenter.shared.show("Gmail connected")
            } catch {
                gmailError = error.localizedDescription
            }
            isAuthorizing = false
        }
    }

    private var modelCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            sectionLabel("Model")
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack {
                    Text("Model ID")
                        .font(Theme.Typography.body())
                        .foregroundStyle(Theme.Palette.inkSoft)
                    Spacer()
                    TextField("claude-opus-4-7", text: $model)
                        .font(.system(.body, design: .monospaced))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(Theme.Palette.ink)
                }

                Divider().background(Theme.Palette.hairline)

                Stepper(value: $maxTokens, in: 256...8192, step: 256) {
                    HStack {
                        Text("Max tokens")
                            .font(Theme.Typography.body())
                            .foregroundStyle(Theme.Palette.inkSoft)
                        Spacer()
                        Text("\(maxTokens)")
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(Theme.Palette.ink)
                    }
                }
            }
            .themedCard(padding: Theme.Spacing.md, cornerRadius: Theme.Radius.card)
        }
    }

    private var debugCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            sectionLabel("Debug")
            VStack(alignment: .leading, spacing: 0) {
                NavigationLink {
                    ClassifierDebugView()
                } label: {
                    HStack {
                        Text("View last classifier run")
                            .font(Theme.Typography.body())
                            .foregroundStyle(Theme.Palette.ink)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.Palette.muted)
                    }
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Divider().background(Theme.Palette.hairline)
                Text("Inspect the prompt sent, raw response, parsed JSON, and per-item routing for the most recent classification round.")
                    .font(Theme.Typography.meta())
                    .foregroundStyle(Theme.Palette.muted)
                    .padding(.top, 6)
            }
            .themedCard(padding: Theme.Spacing.md, cornerRadius: Theme.Radius.card)
        }
    }

    private var actionsRow: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Button {
                save()
            } label: {
                Text("Save")
                    .font(Theme.Typography.bodyEmphasis())
                    .foregroundStyle(Color(uiColor: .systemBackground))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background {
                        RoundedRectangle(cornerRadius: Theme.Radius.chip, style: .continuous)
                            .fill(Theme.Palette.ink)
                    }
            }
            .buttonStyle(.plain)

            Button(role: .destructive) {
                Haptics.light()
                KeychainService.delete(LLMService.apiKeyAccount)
                apiKey = ""
                ToastCenter.shared.show("API key cleared")
            } label: {
                Text("Clear API key")
                    .font(Theme.Typography.body())
                    .foregroundStyle(.red.opacity(0.85))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background {
                        RoundedRectangle(cornerRadius: Theme.Radius.chip, style: .continuous)
                            .fill(.ultraThinMaterial)
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.chip, style: .continuous)
                            .strokeBorder(Color.red.opacity(0.2), lineWidth: 0.5)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func sectionLabel(_ s: String) -> some View {
        Text(s.uppercased())
            .font(Theme.Typography.meta())
            .tracking(1)
            .foregroundStyle(Theme.Palette.muted)
            .padding(.leading, Theme.Spacing.xs)
    }

    private func save() {
        do {
            try KeychainService.save(apiKey, for: LLMService.apiKeyAccount)
            Haptics.success()
            ToastCenter.shared.show("Saved")
        } catch {
            // silently ignore save errors
        }
    }

    private func saveNewsTopic() {
        let trimmed = newsTopic.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = trimmed.isEmpty ? RssProvider.defaultTopic : trimmed
        UserDefaults.standard.set(value, forKey: RssProvider.topicDefaultsKey)
        newsTopic = value
        Haptics.success()
        ToastCenter.shared.show("News topic saved")
    }
}

#Preview {
    SettingsView()
}
