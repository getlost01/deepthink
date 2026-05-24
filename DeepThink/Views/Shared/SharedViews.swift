import SwiftData
import SwiftUI

struct StoryPointsBadge: View {
    let points: Int

    var body: some View {
        Text("\(points)")
            .font(DS.Font.small)
            .fontWeight(.semibold)
            .foregroundStyle(DS.Colors.accent)
            .padding(.horizontal, DS.Spacing.xs2)
            .padding(.vertical, DS.Spacing.xxs)
            .background(DS.Colors.accentFill, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
    }
}

struct TagChip: View {
    let tag: Tag

    var body: some View {
        Text(tag.name)
            .font(DS.Font.small)
            .fontWeight(.medium)
            .foregroundStyle(Color(hex: tag.color))
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xs)
            .background(DS.Colors.badgeFill(Color(hex: tag.color)), in: Capsule())
    }
}

struct StatusIndicator: View {
    let status: TaskStatus

    var body: some View {
        Image(systemName: status.icon)
            .font(.system(size: DS.IconSize.xs))
            .foregroundStyle(status.color)
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }

        return (positions, CGSize(width: maxX, height: y + rowHeight))
    }
}

// MARK: - Deep Link Picker Sheet

struct DeepLinkPickerSheet: View {
    let type: String
    let onSelect: (String, URL) -> Void
    let onDismiss: () -> Void

    @Query private var tasks: [TaskItem]
    @Query private var notes: [Note]
    @Query private var reminders: [Reminder]
    @Query private var projects: [Project]
    @State private var search = ""
    @FocusState private var searchFocused: Bool

    private var knowledgeEntries: [KnowledgeEntry] {
        KnowledgeService.shared.entries
    }

    private var filteredTasks: [TaskItem] {
        tasks.filter { search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) }
            .sorted { (!$0.isArchived && $1.isArchived) || ($0.isArchived == $1.isArchived && $0.modifiedAt > $1.modifiedAt) }
    }

    private var filteredNotes: [Note] {
        notes.filter { search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) }
            .sorted { (!$0.isArchived && $1.isArchived) || ($0.isArchived == $1.isArchived && $0.modifiedAt > $1.modifiedAt) }
    }

    private var filteredReminders: [Reminder] {
        reminders.filter { search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var filteredKnowledge: [KnowledgeEntry] {
        knowledgeEntries.filter { search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) }
            .sorted { $0.importedAt > $1.importedAt }
    }

    private var filteredProjects: [Project] {
        projects.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) }
            .sorted { (!$0.isArchived && $1.isArchived) || ($0.isArchived == $1.isArchived && $0.modifiedAt > $1.modifiedAt) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: linkIcon)
                    .font(.system(size: DS.IconSize.md, weight: .medium))
                    .foregroundStyle(DS.Colors.accent)
                    .frame(width: 32, height: 32)
                    .background(DS.Colors.accentFill, in: RoundedRectangle(cornerRadius: DS.Radius.sm))

                VStack(alignment: .leading, spacing: 1) {
                    Text("Link \(linkLabel)")
                        .font(DS.Font.heading)
                        .foregroundStyle(DS.Colors.textPrimary)
                    Text("Select a \(linkLabel.lowercased()) to insert")
                        .font(DS.Font.small)
                        .foregroundStyle(DS.Colors.textTertiary)
                }

                Spacer()

                Button { onDismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: DS.IconSize.xs, weight: .bold))
                        .foregroundStyle(DS.Colors.textTertiary)
                        .frame(width: 24, height: 24)
                        .background(DS.Colors.fill, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                        .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm).strokeBorder(DS.Colors.border, lineWidth: 1))
                }
                .buttonStyle(.plainPointer)
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)
            .background(DS.Colors.modal)

            Divider()

            // Search
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: DS.IconSize.sm))
                    .foregroundStyle(DS.Colors.textTertiary)
                TextField("Search \(linkLabel.lowercased())s...", text: $search)
                    .textFieldStyle(.plain)
                    .dsThemedTextInput()
                    .font(DS.Font.body)
                    .focused($searchFocused)
                if !search.isEmpty {
                    Button { search = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: DS.IconSize.sm))
                            .foregroundStyle(DS.Colors.textTertiary)
                    }
                    .buttonStyle(.plainPointer)
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm + 2)
            .background(DS.Colors.fillSecondary, in: RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .strokeBorder(DS.Colors.border, lineWidth: 1)
            )
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)
            .animation(DS.Animation.quick, value: search.isEmpty)

            Divider()

            // Count badge
            if !linkItems.isEmpty {
                HStack {
                    Text("\(linkItems.count) \(linkLabel.lowercased())\(linkItems.count == 1 ? "" : "s")")
                        .font(DS.Font.small)
                        .foregroundStyle(DS.Colors.textTertiary)
                    Spacer()
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.sm)
                .padding(.bottom, DS.Spacing.xs)
            }

            if linkItems.isEmpty {
                VStack(spacing: DS.Spacing.md) {
                    Image(systemName: linkIcon)
                        .font(.system(size: DS.IconSize.xxxl, weight: .light))
                        .foregroundStyle(DS.Colors.textTertiary)
                    VStack(spacing: DS.Spacing.xs) {
                        Text(search.isEmpty ? "No \(linkLabel.lowercased())s yet" : "No results for \"\(search)\"")
                            .font(DS.Font.body)
                            .foregroundStyle(DS.Colors.textSecondary)
                        if !search.isEmpty {
                            Button { search = "" } label: {
                                Text("Clear search")
                                    .font(DS.Font.caption)
                                    .foregroundStyle(DS.Colors.accent)
                            }
                            .buttonStyle(.plainPointer)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(linkItems, id: \.0) { _, title, subtitle, url, isArchived in
                            DeepLinkPickerRow(title: title, subtitle: subtitle, url: url, icon: linkIcon, isArchived: isArchived, onSelect: onSelect)
                        }
                    }
                    .padding(.bottom, DS.Spacing.sm)
                }
            }
        }
        .frame(width: 420, height: 480)
        .dsModalChrome()
        .onAppear { searchFocused = true }
    }

    private func deeplink(_ path: String) -> URL {
        URL(string: "deepthink://\(path)") ?? URL(fileURLWithPath: "/")
    }

    private func knowledgeURL(for entry: KnowledgeEntry) -> URL {
        var comps = URLComponents()
        comps.scheme = "deepthink"
        comps.host = "knowledge"
        comps.queryItems = [URLQueryItem(name: "id", value: entry.id)]
        return comps.url ?? deeplink("knowledge")
    }

    private var linkItems: [(String, String, String, URL, Bool)] {
        switch type {
        case "task":
            filteredTasks.map { ($0.id.uuidString, $0.title, $0.status.rawValue, deeplink("task/\($0.id.uuidString)"), $0.isArchived) }
        case "note":
            filteredNotes.map { (
                $0.id.uuidString,
                $0.title,
                $0.modifiedAt.relativeFormatted,
                deeplink("note/\($0.id.uuidString)"),
                $0.isArchived
            ) }
        case "reminder":
            filteredReminders.map { r in
                let subtitle = r.reminderDate.map(\.shortFormatted) ?? (r.isCompleted ? "Completed" : "No date")
                return (r.id.uuidString, r.title, subtitle, deeplink("reminder/\(r.id.uuidString)"), false)
            }
        case "project":
            filteredProjects.map { (
                $0.id.uuidString,
                $0.name,
                "\($0.tasks.count(where: { !$0.isArchived })) tasks",
                deeplink("project/\($0.id.uuidString)"),
                $0.isArchived
            ) }
        case "knowledge":
            filteredKnowledge.map { ($0.id, $0.title, $0.source, knowledgeURL(for: $0), false) }
        default:
            []
        }
    }

    private var linkLabel: String {
        switch type {
        case "task": "Task"
        case "note": "Note"
        case "reminder": "Reminder"
        case "project": "Project"
        case "knowledge": "Knowledge"
        default: "Item"
        }
    }

    private var linkIcon: String {
        switch type {
        case "task": "checkmark.circle"
        case "note": "doc.text"
        case "reminder": "bell"
        case "project": "folder"
        case "knowledge": "brain"
        default: "link"
        }
    }
}

// MARK: - Wiki Link Picker

enum WikiLinkPickerMode {
    case insert
    case edit(currentTitle: String)
}

struct WikiLinkPickerSheet: View {
    let mode: WikiLinkPickerMode
    let onWiki: (KnowledgeEntry) -> Void
    let onReference: (KnowledgeEntry) -> Void
    let onNavigate: ((KnowledgeEntry) -> Void)?
    let onRemove: (() -> Void)?
    let onDismiss: () -> Void

    @State private var search = ""
    @FocusState private var searchFocused: Bool

    private var entries: [KnowledgeEntry] {
        KnowledgeService.shared.entries
    }

    private var filteredEntries: [KnowledgeEntry] {
        entries.filter { search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) }
            .sorted { $0.importedAt > $1.importedAt }
    }

    private var isEdit: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var currentTitle: String? {
        if case let .edit(t) = mode { return t }
        return nil
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: "book.closed")
                    .font(.system(size: DS.IconSize.md, weight: .medium))
                    .foregroundStyle(DS.Colors.accent)
                    .frame(width: 32, height: 32)
                    .background(DS.Colors.accentFill, in: RoundedRectangle(cornerRadius: DS.Radius.sm))

                VStack(alignment: .leading, spacing: 1) {
                    Text(isEdit ? "Edit Knowledge Link" : "Link Knowledge Entry")
                        .font(DS.Font.heading)
                        .foregroundStyle(DS.Colors.textPrimary)
                    Text(isEdit ? "Replace, navigate, or remove" : "Choose wiki link or reference")
                        .font(DS.Font.small)
                        .foregroundStyle(DS.Colors.textTertiary)
                }

                Spacer()

                Button { onDismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: DS.IconSize.xs, weight: .bold))
                        .foregroundStyle(DS.Colors.textTertiary)
                        .frame(width: 24, height: 24)
                        .background(DS.Colors.fill, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                        .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm).strokeBorder(DS.Colors.border, lineWidth: 1))
                }
                .buttonStyle(.plainPointer)
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)
            .background(DS.Colors.modal)

            Divider()

            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: DS.IconSize.sm))
                    .foregroundStyle(DS.Colors.textTertiary)
                TextField("Search knowledge...", text: $search)
                    .textFieldStyle(.plain)
                    .dsThemedTextInput()
                    .font(DS.Font.body)
                    .focused($searchFocused)
                if !search.isEmpty {
                    Button { search = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: DS.IconSize.sm))
                            .foregroundStyle(DS.Colors.textTertiary)
                    }
                    .buttonStyle(.plainPointer)
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm + 2)
            .background(DS.Colors.fillSecondary, in: RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).strokeBorder(DS.Colors.border, lineWidth: 1))
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)
            .animation(DS.Animation.quick, value: search.isEmpty)

            Divider()

            if let title = currentTitle {
                HStack(spacing: DS.Spacing.sm) {
                    Text("[[")
                        .font(DS.Font.mono)
                        .foregroundStyle(DS.Colors.textTertiary)
                    Text(title)
                        .font(DS.Font.mono)
                        .foregroundStyle(DS.Colors.textSecondary)
                        .lineLimit(1)
                    Text("]]")
                        .font(DS.Font.mono)
                        .foregroundStyle(DS.Colors.textTertiary)

                    Spacer()

                    if let onNavigate,
                       let entry = entries.first(where: { $0.title == title }) {
                        Button("Open") { onNavigate(entry); onDismiss() }
                            .buttonStyle(.dsSecondary)
                    }

                    if let onRemove {
                        Button("Remove") { onRemove(); onDismiss() }
                            .buttonStyle(.dsSecondary)
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.sm)
                .background(DS.Colors.fillSecondary)

                Divider()
            }

            if filteredEntries.isEmpty {
                VStack(spacing: DS.Spacing.md) {
                    Image(systemName: "brain")
                        .font(.system(size: DS.IconSize.xxxl, weight: .light))
                        .foregroundStyle(DS.Colors.textTertiary)
                    Text(search.isEmpty ? "No knowledge entries yet" : "No results for \"\(search)\"")
                        .font(DS.Font.body)
                        .foregroundStyle(DS.Colors.textSecondary)
                    if !search.isEmpty {
                        Button { search = "" } label: {
                            Text("Clear search")
                                .font(DS.Font.caption)
                                .foregroundStyle(DS.Colors.accent)
                        }
                        .buttonStyle(.plainPointer)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredEntries, id: \.id) { entry in
                            WikiLinkPickerRow(
                                entry: entry,
                                onWiki: { onWiki(entry); onDismiss() },
                                onReference: { onReference(entry); onDismiss() }
                            )
                        }
                    }
                    .padding(.bottom, DS.Spacing.sm)
                }
            }
        }
        .frame(width: 480, height: 520)
        .dsModalChrome()
        .onAppear { searchFocused = true }
    }
}

private struct WikiLinkPickerRow: View {
    let entry: KnowledgeEntry
    let onWiki: () -> Void
    let onReference: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "brain")
                .font(.system(size: DS.IconSize.sm, weight: .medium))
                .foregroundStyle(isHovered ? DS.Colors.accent : DS.Colors.textSecondary)
                .frame(width: 32, height: 32)
                .background(DS.Colors.fill, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm).strokeBorder(DS.Colors.border, lineWidth: 1))

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(entry.title.isEmpty ? "Untitled" : entry.title)
                    .font(DS.Font.body)
                    .foregroundStyle(DS.Colors.textPrimary)
                    .lineLimit(1)
                Text(entry.source)
                    .font(DS.Font.small)
                    .foregroundStyle(DS.Colors.textTertiary)
                    .lineLimit(1)
            }

            Spacer()

            HStack(spacing: DS.Spacing.xs) {
                Button { onWiki() } label: {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                            .font(.system(size: DS.IconSize.nano, weight: .medium))
                        Text("Wiki")
                            .font(DS.Font.small)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(DS.Colors.accent)
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, DS.Spacing.xs)
                    .background(DS.Colors.accentFill, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                    .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm).strokeBorder(DS.Colors.badgeBorder(DS.Colors.accent), lineWidth: 1))
                }
                .buttonStyle(.plainPointer)

                Button { onReference() } label: {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "link")
                            .font(.system(size: DS.IconSize.nano, weight: .medium))
                        Text("Ref")
                            .font(DS.Font.small)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(DS.Colors.textSecondary)
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, DS.Spacing.xs)
                    .background(DS.Colors.fill, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                    .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm).strokeBorder(DS.Colors.border, lineWidth: 1))
                }
                .buttonStyle(.plainPointer)
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .animation(DS.Animation.quick, value: isHovered)
    }
}

private struct DeepLinkPickerRow: View {
    let title: String
    let subtitle: String
    let url: URL
    let icon: String
    let isArchived: Bool
    let onSelect: (String, URL) -> Void
    @State private var isHovered = false

    var body: some View {
        Button { onSelect(title, url) } label: {
            HStack(spacing: DS.Spacing.md) {
                // Icon badge with optional archive overlay
                ZStack(alignment: .bottomTrailing) {
                    Image(systemName: icon)
                        .font(.system(size: DS.IconSize.sm, weight: .medium))
                        .foregroundStyle(isArchived ? DS.Colors.textTertiary : (isHovered ? DS.Colors.accent : DS.Colors.textSecondary))
                        .frame(width: 32, height: 32)
                        .background(DS.Colors.fill, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                        .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm).strokeBorder(DS.Colors.border, lineWidth: 1))

                    if isArchived {
                        Image(systemName: "archivebox.fill")
                            .font(.system(size: DS.IconSize.nano, weight: .bold))
                            .foregroundStyle(DS.Colors.onAccent)
                            .padding(2)
                            .background(DS.Colors.textTertiary, in: RoundedRectangle(cornerRadius: DS.Radius.xs))
                            .offset(x: 4, y: 4)
                    }
                }

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(title.isEmpty ? "Untitled" : title)
                        .font(DS.Font.body)
                        .foregroundStyle(isArchived ? DS.Colors.textTertiary : DS.Colors.textPrimary)
                        .lineLimit(1)
                    HStack(spacing: DS.Spacing.xs) {
                        if isArchived {
                            Text("Archived")
                                .font(DS.Font.small)
                                .foregroundStyle(DS.Colors.textTertiary)
                        }
                        if !subtitle.isEmpty {
                            if isArchived {
                                Text("·")
                                    .font(DS.Font.small)
                                    .foregroundStyle(DS.Colors.textTertiary)
                            }
                            Text(subtitle)
                                .font(DS.Font.small)
                                .foregroundStyle(DS.Colors.textTertiary)
                                .lineLimit(1)
                        }
                    }
                }

                Spacer()

                Image(systemName: isHovered ? "plus.circle.fill" : "plus.circle")
                    .font(.system(size: DS.IconSize.md))
                    .foregroundStyle(isHovered ? DS.Colors.accent : DS.Colors.textTertiary.opacity(DS.Opacity.faint))
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plainPointer)
        .onHover { isHovered = $0 }
        .animation(DS.Animation.quick, value: isHovered)
    }
}
