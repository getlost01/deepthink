import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(CommandPaletteState.self) private var commandPaletteState
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        if !hasCompletedOnboarding {
            WelcomeView {
                withAnimation(.easeInOut(duration: 0.4)) {
                    hasCompletedOnboarding = true
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
        }
    }
}

struct ContentRouter: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            switch appState.selectedSection {
            case .workspace:
                WorkspaceView()
            case .knowledge:
                KnowledgeView()
            case .ai:
                AIView()
            case .integrations:
                IntegrationsView()
            case .terminal:
                DeepThinkTerminalView()
            case .settings:
                ClaudeSettingsView()
            case nil:
                WorkspaceView()
            }
        }
    }
}
