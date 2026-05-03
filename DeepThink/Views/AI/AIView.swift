import SwiftUI
import SwiftData

struct AIView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        AIChatView(onShowConfig: { tab in
            appState.agentConfigTab = tab
            appState.navigate(to: .integrations)
        })
    }
}
