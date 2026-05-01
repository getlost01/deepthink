import SwiftUI
import SwiftData

enum SettingsTab: String, CaseIterable, Identifiable {
    case tools = "Tools & MCP"
    case memory = "Memory"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .tools: "wrench.and.screwdriver"
        case .memory: "brain"
        }
    }
}

struct SettingsView: View {
    @State private var selectedTab: SettingsTab = .tools

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
            case .tools:
                ToolsHubView()
            case .memory:
                MemoryView()
            }
        }
    }
}
