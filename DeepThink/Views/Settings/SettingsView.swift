import SwiftUI
import SwiftData

enum SettingsTab: String, CaseIterable, Identifiable {
    case claude = "Claude"
    case integrations = "Integrations"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .claude: "sparkles"
        case .integrations: "puzzlepiece.extension"
        }
    }
}

struct SettingsView: View {
    @State private var selectedTab: SettingsTab = .claude

    var body: some View {
        VStack(spacing: 0) {
            DSToolbarBar {
                ForEach(SettingsTab.allCases) { tab in
                    DSTabButton(
                        title: tab.rawValue,
                        icon: tab.icon,
                        isSelected: selectedTab == tab,
                        action: { selectedTab = tab }
                    )
                }
                Spacer()
            }

            Divider()

            switch selectedTab {
            case .claude:
                ClaudeSettingsView()
            case .integrations:
                IntegrationsView()
            }
        }
    }
}
