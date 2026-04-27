import SwiftUI

/// Hidden debug screen — surfaces the most recent `ClassifierService` round so
/// the user can inspect the prompt sent, the raw LLM response, the parsed
/// JSON, and the per-item routing decisions when classification results
/// aren't great. Lives behind Settings → Debug, not on the main UI.
struct ClassifierDebugView: View {
    @ObservedObject private var classifier = ClassifierService.shared

    private let timestampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .medium
        return f
    }()

    var body: some View {
        ZStack {
            Theme.LayeredBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    if let run = classifier.lastRun {
                        header(run)
                        if let err = run.errorDescription {
                            errorBanner(err)
                        }
                        inputRawsCard(run.inputRaws)
                        promptCard(system: run.systemPrompt, user: run.userPrompt)
                        rawResponseCard(run.rawResponse)
                        parsedJSONCard(run.parsedJSONPretty)
                        distributionCard(run.distribution)
                    } else {
                        emptyState
                    }
                    Color.clear.frame(height: 96)
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.md)
            }
        }
        .navigationTitle("Classifier debug")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header / banners

    private func header(_ run: ClassifierDebugRecord) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Last run")
                .font(Theme.Typography.title())
                .foregroundStyle(Theme.Palette.ink)
            Text(timestampFormatter.string(from: run.timestamp))
                .font(Theme.Typography.meta())
                .foregroundStyle(Theme.Palette.muted)
            HStack(spacing: Theme.Spacing.xs) {
                summaryChip(label: "items added", value: "\(run.itemsAdded)")
                summaryChip(label: "raws in", value: "\(run.inputRaws.count)")
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func summaryChip(label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Text(value)
                .font(Theme.Typography.bodyEmphasis())
                .foregroundStyle(Theme.Palette.ink)
            Text(label)
                .font(Theme.Typography.meta())
                .foregroundStyle(Theme.Palette.muted)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(Theme.Palette.hairline, lineWidth: 0.5)
        )
    }

    private func errorBanner(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("ERROR")
                .font(Theme.Typography.meta())
                .tracking(1)
                .foregroundStyle(Color.red.opacity(0.85))
            Text(message)
                .font(Theme.Typography.body())
                .foregroundStyle(Theme.Palette.ink)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .fill(Color.red.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .strokeBorder(Color.red.opacity(0.25), lineWidth: 0.5)
        )
    }

    // MARK: - Sections

    private func inputRawsCard(_ raws: [RawEntry]) -> some View {
        sectionCard(title: "Input raws (\(raws.count))") {
            if raws.isEmpty {
                Text("None.")
                    .font(Theme.Typography.body())
                    .foregroundStyle(Theme.Palette.muted)
            } else {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    ForEach(raws, id: \.id) { e in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(e.text)
                                .font(Theme.Typography.body())
                                .foregroundStyle(Theme.Palette.ink)
                                .textSelection(.enabled)
                            HStack(spacing: 8) {
                                if let t = e.suggestedType {
                                    Text(t.label)
                                        .font(Theme.Typography.meta())
                                        .foregroundStyle(Theme.Palette.muted)
                                }
                                Text(importanceLabel(e.importance))
                                    .font(Theme.Typography.meta())
                                    .foregroundStyle(Theme.Palette.muted)
                                if e.isSensitive {
                                    Text("sensitive")
                                        .font(Theme.Typography.meta())
                                        .foregroundStyle(Theme.Palette.sensitiveAccent)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        if e.id != raws.last?.id {
                            Divider().background(Theme.Palette.hairline)
                        }
                    }
                }
            }
        }
    }

    private func promptCard(system: String, user: String) -> some View {
        CollapsibleMonoCard(title: "Prompt sent",
                            text: "SYSTEM:\n\(system)\n\n---\n\nUSER:\n\(user)")
    }

    private func rawResponseCard(_ raw: String?) -> some View {
        CollapsibleMonoCard(
            title: "Raw LLM response",
            text: raw ?? "(no response — LLM call returned nil)"
        )
    }

    private func parsedJSONCard(_ pretty: String?) -> some View {
        CollapsibleMonoCard(
            title: "Parsed JSON",
            text: pretty ?? "(parse failed — see error banner above)"
        )
    }

    private func distributionCard(_ entries: [ClassifierDebugRecord.DistributionEntry]) -> some View {
        sectionCard(title: "Distribution log (\(entries.count))") {
            if entries.isEmpty {
                Text("No items routed.")
                    .font(Theme.Typography.body())
                    .foregroundStyle(Theme.Palette.muted)
            } else {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    ForEach(Array(entries.enumerated()), id: \.offset) { _, entry in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.rawSnippet)
                                .font(Theme.Typography.body())
                                .foregroundStyle(Theme.Palette.ink)
                                .textSelection(.enabled)
                            HStack(spacing: 6) {
                                Text("→")
                                    .foregroundStyle(Theme.Palette.muted)
                                Text(entry.resolvedType)
                                    .foregroundStyle(Theme.Palette.inkSoft)
                                Text("→")
                                    .foregroundStyle(Theme.Palette.muted)
                                Text(entry.action)
                                    .foregroundStyle(actionColor(entry.action))
                            }
                            .font(Theme.Typography.meta())
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        if entry.rawSnippet != entries.last?.rawSnippet || entry.action != entries.last?.action {
                            Divider().background(Theme.Palette.hairline)
                        }
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.md) {
            Spacer().frame(height: 80)
            Text("No classifier run captured yet.")
                .font(Theme.Typography.emptyState())
                .foregroundStyle(Theme.Palette.ink)
                .multilineTextAlignment(.center)
            Text("Tap Process on the Capture screen with at least one raw entry, then come back.")
                .font(Theme.Typography.body())
                .foregroundStyle(Theme.Palette.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.lg)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Bits

    @ViewBuilder
    private func sectionCard<Content: View>(title: String,
                                            @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(title.uppercased())
                .font(Theme.Typography.meta())
                .tracking(1)
                .foregroundStyle(Theme.Palette.muted)
                .padding(.leading, Theme.Spacing.xs)
            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .themedCard(padding: Theme.Spacing.md, cornerRadius: Theme.Radius.card)
        }
    }

    private func importanceLabel(_ i: Importance) -> String {
        switch i {
        case .low: return "low"
        case .medium: return "medium"
        case .high: return "high"
        case .critical: return "critical"
        }
    }

    private func actionColor(_ action: String) -> Color {
        if action.hasPrefix("added") { return Color.green.opacity(0.8) }
        if action.hasPrefix("skipped") { return Color.orange.opacity(0.85) }
        return Theme.Palette.muted
    }
}

// MARK: - Collapsible monospace block

private struct CollapsibleMonoCard: View {
    let title: String
    let text: String
    @State private var expanded: Bool = false

    private var preview: String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 240 { return trimmed }
        return String(trimmed.prefix(240)) + "…"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text(title.uppercased())
                    .font(Theme.Typography.meta())
                    .tracking(1)
                    .foregroundStyle(Theme.Palette.muted)
                Spacer()
                Button {
                    Haptics.soft()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        expanded.toggle()
                    }
                } label: {
                    Text(expanded ? "Collapse" : "Expand")
                        .font(Theme.Typography.meta())
                        .foregroundStyle(Theme.Palette.inkSoft)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Theme.Spacing.xs)

            VStack(alignment: .leading, spacing: 0) {
                Text(expanded ? text : preview)
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(Theme.Palette.ink)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(Theme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .fill(Theme.Palette.paper)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .strokeBorder(Theme.Palette.hairline, lineWidth: 0.5)
            )
        }
    }
}

#Preview {
    NavigationStack {
        ClassifierDebugView()
    }
}
