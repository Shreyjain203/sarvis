import SwiftUI

struct RootView: View {
    enum Tab: Hashable { case capture, today, library }

    @State private var tab: Tab = .capture
    @Namespace private var indicatorNS
    @State private var showCaptureSheet = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.LayeredBackground()

            Group {
                switch tab {
                case .capture: InputView()
                case .today:   TodayView()
                case .library: ProcessedView()
                }
            }
            .transition(.opacity.combined(with: .move(edge: .bottom)))
            .animation(.easeInOut(duration: 0.25), value: tab)

            CustomTabBar(tab: $tab, ns: indicatorNS)
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.bottom, Theme.Spacing.sm)
        }
        .toastHost()
        .onOpenURL { url in
            if url.scheme == "sarvis" && url.host == "capture" {
                showCaptureSheet = true
            }
        }
        .sheet(isPresented: $showCaptureSheet) {
            QuickCaptureSheet()
        }
    }
}

private struct CustomTabBar: View {
    @Binding var tab: RootView.Tab
    var ns: Namespace.ID

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            tabButton(.capture, label: "Capture", icon: "square.and.pencil")
            tabButton(.today, label: "Entries", icon: "tray")
            tabButton(.library, label: "Library", icon: "tray.full")
        }
        .padding(Theme.Spacing.xs)
        .background {
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
        }
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(Theme.Palette.hairline, lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.10), radius: 18, x: 0, y: 8)
    }

    @ViewBuilder
    private func tabButton(_ id: RootView.Tab, label: String, icon: String) -> some View {
        let isActive = tab == id
        Button {
            guard tab != id else { return }
            Haptics.soft()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                tab = id
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                Text(label)
                    .font(Theme.Typography.tab())
            }
            .foregroundStyle(isActive ? Theme.Palette.ink : Theme.Palette.muted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background {
                if isActive {
                    Capsule(style: .continuous)
                        .fill(Theme.Palette.ink.opacity(0.08))
                        .overlay(
                            Capsule(style: .continuous)
                                .strokeBorder(Theme.Palette.hairline, lineWidth: 0.5)
                        )
                        .matchedGeometryEffect(id: "tabIndicator", in: ns)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    RootView().environmentObject(TodoStore.shared)
}
