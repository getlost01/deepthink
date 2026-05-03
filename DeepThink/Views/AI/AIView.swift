import SwiftUI
import SwiftData

struct AIView: View {
    @Environment(AppState.self) private var appState
    @State private var aiTab: AgentConfigTab?

    var body: some View {
        VStack(spacing: 0) {
            if let tab = aiTab {
                VStack(spacing: 0) {
                    HStack(spacing: DS.Spacing.md) {
                        Button {
                            withAnimation(DS.Animation.standard) { aiTab = nil }
                        } label: {
                            HStack(spacing: DS.Spacing.xs) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 10, weight: .bold))
                                Text("Back to Chat")
                                    .font(DS.Font.caption)
                            }
                            .foregroundStyle(DS.Colors.accent)
                        }
                        .buttonStyle(.plainPointer)

                        Spacer()

                        ForEach(AgentConfigTab.allCases) { t in
                            DSTabButton(title: t.rawValue, isSelected: tab == t) {
                                aiTab = t
                            }
                        }

                        Spacer()
                    }
                    .frame(height: DS.Layout.toolbarHeight)
                    .padding(.horizontal, DS.Spacing.lg)
                    .background(.bar)

                    Divider()

                    Group {
                        switch tab {
                        case .agents:
                            AgentListView()
                        case .skillsAndRules:
                            SkillsRulesView()
                        }
                    }
                }
            } else {
                AIChatView(onShowConfig: { tab in
                    withAnimation(DS.Animation.standard) { aiTab = tab }
                })
            }
        }
        .onChange(of: appState.agentConfigTab) { _, newTab in
            if appState.selectedSection == .ai {
                aiTab = newTab
            }
        }
    }
}
