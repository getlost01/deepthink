import SwiftUI

struct ContextFeedView: View {
    var searchText: String = ""
    @Environment(AppState.self) private var appState
    @State private var filterSource: String?
    @State private var items: [ContextItem] = []
    @State private var selectedItem: ContextItem?

    private let service = ContextService.shared

    var body: some View {
        VStack(spacing: 0) {
            // Source filter pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Spacing.sm) {
                    filterPill(title: "All", source: nil)

                    ForEach(service.sources) { source in
                        filterPill(title: source.name, source: source.id, icon: source.icon, color: source.color)
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.sm)
            }
            .background(.bar)

            Divider()

            if filteredItems.isEmpty {
                DSEmptyState(
                    icon: "clock",
                    title: "No Context Items",
                    subtitle: "Captured context from your integrations will appear here in chronological order."
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(filteredItems) { item in
                            feedRow(item)
                        }
                    }
                    .padding(.vertical, DS.Spacing.sm)
                }
            }
        }
        .onAppear { loadAllItems() }
        .sheet(item: $selectedItem) { item in
            NavigationStack {
                ContextItemView(item: item)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { selectedItem = nil }
                        }
                    }
            }
            .frame(minWidth: 600, minHeight: 500)
        }
    }

    private var filteredItems: [ContextItem] {
        var result = items

        if let filterSource {
            result = result.filter { $0.source == filterSource }
        }

        if !searchText.isEmpty {
            result = result.filter { $0.content.localizedCaseInsensitiveContains(searchText) }
        }

        return result
    }

    private func loadAllItems() {
        var all: [ContextItem] = []
        for source in service.sources {
            all.append(contentsOf: service.loadItems(source: source.id))
        }
        items = all.sorted { $0.timestamp > $1.timestamp }
    }

    // MARK: - Components

    @ViewBuilder
    private func filterPill(title: String, source: String?, icon: String? = nil, color: Color = DS.Colors.accent) -> some View {
        let isSelected = filterSource == source

        Button {
            filterSource = source
        } label: {
            HStack(spacing: DS.Spacing.xs) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: DS.IconSize.xs, weight: .medium))
                }
                Text(title)
                    .font(DS.Font.caption)
                    .fontWeight(.medium)
            }
            .foregroundStyle(isSelected ? .white : DS.Colors.textSecondary)
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .background(
                isSelected ? color : DS.Colors.inputBg,
                in: Capsule()
            )
        }
        .buttonStyle(.plainPointer)
    }

    @ViewBuilder
    private func feedRow(_ item: ContextItem) -> some View {
        Button {
            selectedItem = item
        } label: {
            HStack(alignment: .top, spacing: DS.Spacing.md) {
                DSIconBadge(
                    icon: ContextService.iconForSource(item.source),
                    color: ContextService.colorForSource(item.source),
                    size: 28
                )

                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    HStack(spacing: DS.Spacing.sm) {
                        DSPill(text: item.source.capitalized, color: ContextService.colorForSource(item.source))
                        DSPill(text: item.channel, color: DS.Colors.textSecondary)
                        Spacer()
                        Text(item.timestamp.relativeFormatted)
                            .font(DS.Font.tiny)
                            .foregroundStyle(DS.Colors.textTertiary)
                    }

                    // Content preview: first 2 lines
                    let preview = item.content
                        .components(separatedBy: "\n")
                        .prefix(2)
                        .joined(separator: " ")
                        .trimmingCharacters(in: .whitespacesAndNewlines)

                    Text(preview)
                        .font(DS.Font.body)
                        .foregroundStyle(DS.Colors.textSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)
            .background(DS.Colors.subtleBg, in: RoundedRectangle(cornerRadius: DS.Radius.md))
        }
        .buttonStyle(.plainPointer)
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, 1)
    }
}
