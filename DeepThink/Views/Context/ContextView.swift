import SwiftUI

enum ContextTab: String, CaseIterable {
    case browse = "Browse"
    case feed = "Feed"

    var icon: String {
        switch self {
        case .browse: "folder"
        case .feed: "clock"
        }
    }
}

struct ContextView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedTab: ContextTab = .browse
    @State private var searchText: String = ""

    private let service = ContextService.shared

    var body: some View {
        VStack(spacing: 0) {
            DSToolbarBar {
                DSTabButton(
                    title: ContextTab.browse.rawValue,
                    icon: ContextTab.browse.icon,
                    isSelected: selectedTab == .browse,
                    action: { selectedTab = .browse }
                )
                DSTabButton(
                    title: ContextTab.feed.rawValue,
                    icon: ContextTab.feed.icon,
                    isSelected: selectedTab == .feed,
                    action: { selectedTab = .feed }
                )

                Spacer()

                DSSearchField(text: $searchText, placeholder: "Search context...")
                    .frame(maxWidth: 240)
            }

            Divider()

            switch selectedTab {
            case .browse:
                browseContent
            case .feed:
                ContextFeedView(searchText: searchText)
            }
        }
        .onAppear {
            service.loadSources()
        }
    }

    @ViewBuilder
    private var browseContent: some View {
        HSplitView {
            SourceBrowserView()
                .frame(minWidth: 240, idealWidth: 280, maxWidth: 360)

            if let path = appState.selectedContextItemPath,
               let item = service.loadItem(at: path) {
                ContextItemView(item: item)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let source = appState.selectedContextSource {
                let items: [ContextItem] = {
                    if !searchText.isEmpty {
                        return service.loadItems(source: source, channel: appState.selectedContextChannel)
                            .filter { $0.content.localizedCaseInsensitiveContains(searchText) }
                    }
                    return service.loadItems(source: source, channel: appState.selectedContextChannel)
                }()
                contextItemList(items: items)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                DSEmptyState(
                    icon: "tray.full",
                    title: "Select a Source",
                    subtitle: "Browse captured context from your integrations and project knowledge."
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func contextItemList(items: [ContextItem]) -> some View {
        if items.isEmpty {
            DSEmptyState(
                icon: "doc.text",
                title: "No Items",
                subtitle: "No context items found for this source."
            )
        } else {
            List(items) { item in
                Button {
                    appState.selectedContextItemPath = item.filePath
                } label: {
                    HStack(spacing: DS.Spacing.md) {
                        Image(systemName: ContextService.iconForSource(item.source))
                            .font(.system(size: DS.IconSize.sm))
                            .foregroundStyle(ContextService.colorForSource(item.source))
                            .frame(width: 20)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.channel)
                                .font(DS.Font.body)
                                .fontWeight(.medium)
                                .lineLimit(1)

                            Text(item.content.prefix(80).replacingOccurrences(of: "\n", with: " "))
                                .font(DS.Font.caption)
                                .foregroundStyle(DS.Colors.textSecondary)
                                .lineLimit(2)
                        }

                        Spacer()

                        Text(item.timestamp.relativeFormatted)
                            .font(DS.Font.small)
                            .foregroundStyle(DS.Colors.textTertiary)
                    }
                    .padding(.vertical, DS.Spacing.xs)
                }
                .buttonStyle(.plain)
                .listRowBackground(
                    appState.selectedContextItemPath == item.filePath
                        ? DS.Colors.accentFill
                        : Color.clear
                )
            }
            .listStyle(.plain)
        }
    }
}
