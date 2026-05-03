import SwiftUI
import SwiftData

struct AgentConfigView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState

        VStack(spacing: 0) {
            DSToolbarBar {
                ForEach(AgentConfigTab.allCases) { tab in
                    DSTabButton(
                        title: tab.rawValue,
                        icon: tab.icon,
                        isSelected: appState.agentConfigTab == tab
                    ) {
                        withAnimation(DS.Animation.quick) {
                            appState.agentConfigTab = tab
                        }
                    }
                }
                Spacer()
                DSHelpButton(text: SidebarSection.ai.helpText)
            }

            Divider()

            Group {
                switch appState.agentConfigTab {
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
