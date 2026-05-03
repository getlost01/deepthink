import SwiftUI

enum KnowledgeTab: String, CaseIterable, Identifiable {
    case browse = "Browse"
    case search = "Search"
    case timeline = "What's New"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .browse: "book"
        case .search: "sparkle.magnifyingglass"
        case .timeline: "clock.arrow.circlepath"
        }
    }
}

struct KnowledgeView: View {
    @State private var selectedTab: KnowledgeTab = .browse

    var body: some View {
        VStack(spacing: 0) {
            DSToolbarBar {
                ForEach(KnowledgeTab.allCases) { tab in
                    DSTabButton(
                        title: tab.rawValue,
                        icon: tab.icon,
                        isSelected: selectedTab == tab
                    ) {
                        withAnimation(DS.Animation.quick) {
                            selectedTab = tab
                        }
                    }
                }
                Spacer()
                DSHelpButton(text: SidebarSection.knowledge.helpText)
            }

            Divider()

            Group {
                switch selectedTab {
                case .browse:
                    KnowledgeBrowserView()
                case .search:
                    DeepSearchView()
                case .timeline:
                    KnowledgeTimelineView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .dsPage()
    }
}
