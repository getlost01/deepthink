import SwiftUI
import SwiftData

struct AIView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState

        VStack(spacing: 0) {
            DSToolbarBar {
                ForEach(AIMode.allCases) { mode in
                    DSTabButton(
                        title: mode.rawValue,
                        icon: mode.icon,
                        isSelected: appState.aiMode == mode,
                        action: { appState.aiMode = mode }
                    )
                }
                Spacer()
            }

            Divider()

            switch appState.aiMode {
            case .chat:
                AIChatView()
            case .search:
                DeepSearchView()
            case .analyze:
                AnalysisView()
            }
        }
    }
}
