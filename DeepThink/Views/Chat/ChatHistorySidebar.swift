import SwiftUI
import SwiftData

struct ChatHistorySidebar: View {
    let conversations: [Conversation]
    let currentID: UUID?
    let onSelect: (Conversation) -> Void
    let onDelete: (Conversation) -> Void
    let onNewChat: () -> Void
    var onClose: (() -> Void)? = nil
    @State private var searchText = ""
    @State private var hoveredID: UUID?

    private var filtered: [Conversation] {
        let convs = conversations.prefix(100).map { $0 }
        if searchText.isEmpty { return convs }
        let q = searchText.lowercased()
        return convs.filter { $0.title.lowercased().contains(q) }
    }

    private struct Section: Identifiable {
        let title: String
        let items: [Conversation]
        var id: String { title }
    }

    private var sections: [Section] {
        let cal = Calendar.current
        let now = Date()
        let grouped = Dictionary(grouping: filtered) { (conv: Conversation) -> String in
            if cal.isDateInToday(conv.updatedAt) { return "Today" }
            if cal.isDateInYesterday(conv.updatedAt) { return "Yesterday" }
            if conv.updatedAt > cal.date(byAdding: .day, value: -7, to: now)! { return "This Week" }
            return "Older"
        }
        return ["Today", "Yesterday", "This Week", "Older"]
            .compactMap { key in
                guard let items = grouped[key], !items.isEmpty else { return nil }
                return Section(title: key, items: items)
            }
    }

    private let pad: CGFloat = 12

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("History")
                    .font(DS.Font.heading)
                    .foregroundStyle(DS.Colors.textPrimary)
                Spacer()
                if let onClose {
                    DSToolbarButton(icon: "xmark", color: DS.Colors.textTertiary, size: DS.IconSize.sm) {
                        onClose()
                    }
                }
            }
            .padding(.horizontal, pad)
            .frame(height: DS.Layout.toolbarHeight)

            Divider()

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 10))
                    .foregroundStyle(DS.Colors.textTertiary)
                TextField("Search...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(DS.Colors.fill, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
            .padding(.horizontal, pad)
            .padding(.vertical, 8)

            if filtered.isEmpty {
                Spacer()
                VStack(spacing: 6) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 18, weight: .light))
                        .foregroundStyle(DS.Colors.textTertiary)
                    Text(searchText.isEmpty ? "No conversations" : "No results")
                        .font(.system(size: 11))
                        .foregroundStyle(DS.Colors.textTertiary)
                }
                Spacer()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(sections) { section in
                            Text(section.title)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(DS.Colors.textTertiary)
                                .textCase(.uppercase)
                                .padding(.horizontal, pad)
                                .padding(.top, 10)
                                .padding(.bottom, 4)

                            ForEach(section.items) { conv in
                                HistoryRow(
                                    conversation: conv,
                                    isSelected: currentID == conv.id,
                                    isHovered: hoveredID == conv.id,
                                    onSelect: { onSelect(conv) },
                                    onDelete: { onDelete(conv) }
                                )
                                .onHover { hoveredID = $0 ? conv.id : nil }
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.bottom, 8)
                }
            }
        }
        .background(DS.Colors.surfaceElevated)
    }
}

private struct HistoryRow: View {
    let conversation: Conversation
    let isSelected: Bool
    let isHovered: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 6) {
                Image(systemName: "bubble.left")
                    .font(.system(size: 9))
                    .foregroundStyle(isSelected ? DS.Colors.accent : DS.Colors.textTertiary)
                    .frame(width: 14)

                VStack(alignment: .leading, spacing: 1) {
                    Text(conversation.title.isEmpty ? "Untitled" : conversation.title)
                        .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(DS.Colors.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        if let agent = conversation.agentName {
                            Text(agent)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(DS.Colors.accent)
                        }
                        Text(conversation.updatedAt.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
                            .font(.system(size: 9))
                            .foregroundStyle(DS.Colors.textTertiary)
                    }
                }

                Spacer(minLength: 0)

                if isHovered {
                    Button(action: onDelete) {
                        Image(systemName: "xmark")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(DS.Colors.textTertiary)
                    }
                    .buttonStyle(.plainPointer)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                isSelected ? DS.Colors.accentFill :
                    (isHovered ? DS.Colors.fillSecondary : .clear),
                in: RoundedRectangle(cornerRadius: DS.Radius.sm)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plainPointer)
    }
}
