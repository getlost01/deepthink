import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(CommandPaletteState.self) private var commandPaletteState
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var isReady = false

    var body: some View {
        if !hasCompletedOnboarding {
            WelcomeView {
                withAnimation(.easeInOut(duration: 0.4)) {
                    hasCompletedOnboarding = true
                }
            }
        } else if !isReady {
            SplashView()
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            isReady = true
                        }
                    }
                }
        } else {
            HStack(spacing: 0) {
                SidebarView()

                Divider()

                VStack(spacing: 0) {
                    GlobalHeader()
                    Divider()
                    ContentRouter()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .overlay {
                if appState.showCommandPalette {
                    CommandPaletteView()
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
            }
            .transition(.opacity)
        }
    }
}

private struct GlobalHeader: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            navButton(icon: "chevron.left", enabled: appState.canGoBack) {
                appState.navigateBack()
            }
            navButton(icon: "chevron.right", enabled: appState.canGoForward) {
                appState.navigateForward()
            }

            Button { appState.toggleCommandPalette() } label: {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: DS.IconSize.xs, weight: .medium))
                        .foregroundStyle(DS.Colors.textTertiary)
                    Text("Quick Spotlight Search")
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Colors.textSecondary)
                    HStack(spacing: 1) {
                        Image(systemName: "command")
                            .font(.system(size: 9, weight: .medium))
                        Text("K")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .foregroundStyle(DS.Colors.textTertiary)
                    .padding(.horizontal, DS.Spacing.xs)
                    .padding(.vertical, 2)
                    .background(DS.Colors.fill, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                    .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm).strokeBorder(DS.Colors.border, lineWidth: 1))
                }
                .padding(.horizontal, DS.Spacing.md)
                .frame(height: 28)
                .background(DS.Colors.fill, in: RoundedRectangle(cornerRadius: DS.Radius.md))
                .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).strokeBorder(DS.Colors.border, lineWidth: 1))
            }
            .buttonStyle(.plainPointer)
            .keyboardShortcut("k", modifiers: .command)

            Spacer()
        }
        .frame(height: DS.Layout.toolbarHeight)
        .padding(.horizontal, DS.Spacing.lg)
        .background(DS.Colors.surface)
    }

    private func navButton(icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        DSToolbarButton(
            icon: icon,
            color: enabled ? DS.Colors.textPrimary : DS.Colors.textTertiary,
            size: DS.IconSize.xs,
            action: { withAnimation(DS.Animation.standard) { action() } }
        )
        .disabled(!enabled)
    }
}

private struct SplashView: View {
    @State private var dotCount = 0
    private let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 80, height: 80)

            Text("DeepThink")
                .font(DS.Font.display)
                .foregroundStyle(DS.Colors.textPrimary)

            Text("Loading workspace" + String(repeating: ".", count: dotCount))
                .font(DS.Font.caption)
                .foregroundStyle(DS.Colors.textTertiary)
                .frame(width: 120, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DS.Colors.surface)
        .onReceive(timer) { _ in
            dotCount = (dotCount + 1) % 4
        }
    }
}

struct ContentRouter: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        switch appState.selectedSection {
        case .recent: RecentView()
        case .workspace: WorkspaceView()
        case .knowledge: KnowledgeView()
        case .aiAssistant: AIView()
        case .reminders: ReminderListView()
        case .integrations: IntegrationsView()
        case .terminal: DeepThinkTerminalView()
        case .contextGraph: ContextGraphView()
        case .settings: SettingsView()
        case nil: RecentView()
        }
    }
}
