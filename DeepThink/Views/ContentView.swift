import SwiftUI
import SwiftData

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

                ContentRouter()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        Group {
            switch appState.selectedSection {
            case .recent:
                RecentView()
            case .workspace:
                WorkspaceView()
            case .knowledge:
                KnowledgeView()
            case .aiAssistant:
                AIView()
            case .reminders:
                ReminderListView()
            case .integrations:
                IntegrationsView()
            case .terminal:
                DeepThinkTerminalView()
            case .settings:
                SettingsView()
            case nil:
                RecentView()
            }
        }
    }
}
