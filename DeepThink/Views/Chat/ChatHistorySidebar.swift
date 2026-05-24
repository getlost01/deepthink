import SwiftData
import SwiftUI

struct ChatHistorySidebar: View {
    let conversations: [Conversation]
    let currentID: UUID?
    let onSelect: (Conversation) -> Void
    let onDelete: (Conversation) -> Void
    let onNewChat: () -> Void
    var onClose: (() -> Void)?
    @State private var searchText = ""
    @State private var hoveredID: UUID?

    private var filtered: [Conversation] {
        let convs = conversations.prefix(100).map(\.self)
        if searchText.isEmpty { return convs }
        let q = searchText.lowercased()
        return convs.filter { $0.title.lowercased().contains(q) }
    }

    private struct Section: Identifiable {
        let title: String
        let items: [Conversation]
        var id: String {
            title
        }
    }

    private var sections: [Section] {
        let cal = Calendar.current
        let now = Date()
        let grouped = Dictionary(grouping: filtered) { (conv: Conversation) -> String in
            if cal.isDateInToday(conv.updatedAt) { return "Today" }
            if cal.isDateInYesterday(conv.updatedAt) { return "Yesterday" }
            if conv.updatedAt > (cal.date(byAdding: .day, value: -7, to: now) ?? now) { return "This Week" }
            return "Older"
        }
        return ["Today", "Yesterday", "This Week", "Older"]
            .compactMap { key in
                guard let items = grouped[key], !items.isEmpty else { return nil }
                return Section(title: key, items: items)
            }
    }

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
            .padding(.horizontal, DS.Spacing.lg)
            .frame(height: DS.Layout.toolbarHeight)

            Divider()

            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: DS.IconSize.sm))
                    .foregroundStyle(DS.Colors.textTertiary)
                TextField("Search...", text: $searchText)
                    .textFieldStyle(.plain)
                    .dsThemedTextInput()
                    .font(DS.Font.caption)
            }
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xs2)
            .background(DS.Colors.fill, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)

            if filtered.isEmpty {
                Spacer()
                VStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: DS.IconSize.xl, weight: .light))
                        .foregroundStyle(DS.Colors.textTertiary)
                    Text(searchText.isEmpty ? "No conversations" : "No results")
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Colors.textTertiary)
                }
                Spacer()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                        ForEach(sections) { section in
                            Text(section.title)
                                .font(DS.Font.micro)
                                .fontWeight(.bold)
                                .foregroundStyle(DS.Colors.textTertiary)
                                .textCase(.uppercase)
                                .padding(.horizontal, DS.Spacing.sm)
                                .padding(.top, DS.Spacing.lg)
                                .padding(.bottom, DS.Spacing.xs2)

                            ForEach(section.items) { conv in
                                HistoryRow(
                                    conversation: conv,
                                    isSelected: currentID == conv.id,
                                    isHovered: hoveredID == conv.id,
                                    onSelect: { onSelect(conv) },
                                    onDelete: { onDelete(conv) }
                                )
                                .onHover { hoveredID = $0 ? conv.id : nil }
                                .pointerOnHover()
                            }
                        }
                    }
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.bottom, DS.Spacing.md)
                }
            }
        }
        .background(DS.Colors.page)
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
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "bubble.left")
                    .font(.system(size: DS.IconSize.xs))
                    .foregroundStyle(isSelected ? DS.Colors.accent : DS.Colors.textTertiary)
                    .frame(width: DS.IconSize.md)

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(conversation.title.isEmpty ? "Untitled" : conversation.title)
                        .font(DS.Font.caption)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .foregroundStyle(DS.Colors.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: DS.Spacing.xs) {
                        if let agent = conversation.agentName {
                            Text(agent)
                                .font(DS.Font.micro)
                                .foregroundStyle(DS.Colors.accent)
                        }
                        Text(conversation.updatedAt.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
                            .font(DS.Font.micro)
                            .fontWeight(.regular)
                            .foregroundStyle(DS.Colors.textTertiary)
                    }
                }

                Spacer(minLength: 0)

                if isHovered {
                    Button(action: onDelete) {
                        Image(systemName: "xmark")
                            .font(DS.Font.badge)
                            .foregroundStyle(DS.Colors.textTertiary)
                    }
                    .buttonStyle(.plainPointer)
                }
            }
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.sm2)
            .background(
                isSelected ? DS.Colors.accentFill :
                    (isHovered ? DS.Colors.fillSecondary : DS.Colors.transparent),
                in: RoundedRectangle(cornerRadius: DS.Radius.sm)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.sm)
                    .strokeBorder(
                        isSelected ? DS.Colors.badgeBorder(DS.Colors.accent) :
                            (isHovered ? DS.Colors.borderHover : DS.Colors.transparent),
                        lineWidth: 1
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plainPointer)
    }
}
