import SwiftUI
import SwiftData

struct AutomationView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState

        VStack(spacing: 0) {
            DSToolbarBar {
                ForEach(AutomationTab.allCases) { tab in
                    DSTabButton(
                        title: tab.rawValue,
                        icon: tab.icon,
                        isSelected: appState.automationTab == tab
                    ) {
                        withAnimation(DS.Animation.quick) {
                            appState.automationTab = tab
                        }
                    }
                }
                Spacer()
            }

            Divider()

            Group {
                switch appState.automationTab {
                case .knowledge:
                    KnowledgeBrowserView()
                case .agents:
                    AgentListView()
                case .skillsAndRules:
                    SkillsRulesView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .dsPage()
    }
}
