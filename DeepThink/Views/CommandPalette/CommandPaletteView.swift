import SwiftData
import SwiftUI

struct CommandPaletteView: View {
    @Environment(AppState.self) private var appState
    @Environment(CommandPaletteState.self) private var state
    @Query private var notes: [Note]
    @Query private var tasks: [TaskItem]
    @Query private var projects: [Project]
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        @Bindable var state = state

        ZStack {
            DS.Colors.overlayBg
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    // Search bar
                    HStack(spacing: DS.Spacing.sm) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: DS.IconSize.md))
                            .foregroundStyle(DS.Colors.textTertiary)

                        if let prefix = state.activePrefix {
                            Text(prefixLabel(prefix))
                                .font(DS.Font.small)
                                .fontWeight(.medium)
                                .foregroundStyle(DS.Colors.onAccent)
                                .padding(.horizontal, DS.Spacing.sm)
                                .padding(.vertical, 3)
                                .background(DS.Colors.accent, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                        }

                        TextField(placeholderText(state.activePrefix), text: $state.query)
                            .textFieldStyle(.plain)
                            .font(.system(size: DS.IconSize.lg))
                            .focused($isSearchFocused)
                            .onSubmit {
                                if state.executeSelected() { dismiss() }
                            }
                            .onKeyPress(.escape) { dismiss(); return .handled }
                            .onKeyPress(.upArrow) { state.moveUp(); return .handled }
                            .onKeyPress(.downArrow) { state.moveDown(); return .handled }

                        if !state.query.isEmpty {
                            Button { state.query = "" } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: DS.IconSize.sm))
                                    .foregroundStyle(DS.Colors.textTertiary)
                            }
                            .buttonStyle(.plainPointer)
                        }
                    }
                    .padding(DS.Spacing.lg)
                    .onHover { hovering in
                        if hovering { NSCursor.iBeam.push() } else { NSCursor.pop() }
                    }

                    Rectangle()
                        .fill(DS.Colors.border)
                        .frame(height: 0.5)

                    ScrollViewReader { proxy in
                        ScrollView(showsIndicators: false) {
                            LazyVStack(alignment: .leading, spacing: 0) {
                                let sections = state.sections
                                let flatItems = state.allFlatItems

                                // Recent items in empty state
                                if state.query.isEmpty {
                                    recentSection
                                }

                                ForEach(sections) { section in
                                    Text(section.title.uppercased())
                                        .font(DS.Font.micro)
                                        .fontWeight(.bold)
                                        .foregroundStyle(DS.Colors.textTertiary)
                                        .padding(.horizontal, DS.Spacing.lg)
                                        .padding(.top, DS.Spacing.md)
                                        .padding(.bottom, DS.Spacing.xs)

                                    ForEach(Array(section.items.enumerated()), id: \.element.id) { _, item in
                                        let itemIndex = flatItems.firstIndex(where: { $0.id == item.id }) ?? 0
                                        PaletteItemRow(item: item, isSelected: itemIndex == state.selectedIndex)
                                            .id(item.id)
                                            .onTapGesture {
                                                switch item {
                                                case let .command(cmd): cmd.action()
                                                case let .workspaceItem(ws): ws.action()
                                                }
                                                dismiss()
                                            }
                                    }
                                }

                                if flatItems.isEmpty, !state.query.isEmpty {
                                    VStack(spacing: DS.Spacing.sm) {
                                        Image(systemName: "magnifyingglass")
                                            .font(.system(size: DS.IconSize.xl, weight: .light))
                                            .foregroundStyle(DS.Colors.textTertiary)
                                        Text("No results for \"\(state.query)\"")
                                            .font(DS.Font.body)
                                            .foregroundStyle(DS.Colors.textTertiary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(DS.Spacing.xxl)
                                }
                            }
                            .padding(.vertical, DS.Spacing.sm)
                        }
                        .frame(maxHeight: 420)
                        .onChange(of: state.selectedIndex) { _, newValue in
                            let items = state.allFlatItems
                            if items.indices.contains(newValue) {
                                proxy.scrollTo(items[newValue].id, anchor: .center)
                            }
                        }
                        .onChange(of: state.query) {
                            let items = state.allFlatItems
                            if let first = items.first {
                                proxy.scrollTo(first.id, anchor: .top)
                            }
                        }
                    }

                    Rectangle()
                        .fill(DS.Colors.border)
                        .frame(height: 0.5)

                    HStack(spacing: DS.Spacing.lg) {
                        HStack(spacing: DS.Spacing.xs) {
                            KeyHint("↑↓")
                            Text("navigate")
                        }
                        HStack(spacing: DS.Spacing.xs) {
                            KeyHint("↵")
                            Text("open")
                        }
                        HStack(spacing: DS.Spacing.xs) {
                            KeyHint("esc")
                            Text("close")
                        }
                        Spacer()
                        HStack(spacing: DS.Spacing.xs) {
                            KeyHint(">")
                            KeyHint("#")
                            KeyHint("@")
                            KeyHint("%")
                        }
                        Text("filter by type")
                            .foregroundStyle(DS.Colors.textTertiary)
                    }
                    .font(DS.Font.small)
                    .foregroundStyle(DS.Colors.textTertiary)
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.sm)
                }
                .frame(width: 540)

                // Preview pane
                if let preview = selectedPreview {
                    Divider().frame(maxHeight: .infinity)
                    VStack(alignment: .leading, spacing: DS.Spacing.md) {
                        HStack(spacing: DS.Spacing.sm) {
                            Image(systemName: preview.icon)
                                .font(.system(size: DS.IconSize.sm, weight: .medium))
                                .foregroundStyle(preview.color)
                                .frame(width: 28, height: 28)
                                .background(preview.color.opacity(0.12), in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(preview.title)
                                    .font(DS.Font.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(DS.Colors.textPrimary)
                                    .lineLimit(1)
                                Text(preview.typeLabel)
                                    .font(DS.Font.small)
                                    .foregroundStyle(DS.Colors.textTertiary)
                            }
                        }
                        Divider()
                        Text(preview.body)
                            .font(DS.Font.small)
                            .foregroundStyle(DS.Colors.textSecondary)
                            .lineLimit(12)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                        Spacer()
                    }
                    .padding(DS.Spacing.lg)
                    .frame(width: 220)
                }
            }
            .frame(width: selectedPreview != nil ? 760 : 540)
            .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.lg))
            .overlay {
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .strokeBorder(DS.Colors.fill, lineWidth: 0.5)
            }
            .shadow(color: DS.Colors.modalShadow, radius: 30, y: 10)
            .padding(.top, 80)
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .onAppear {
            state.reset()
            updateWorkspaceItems()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                isSearchFocused = true
            }
        }
        .onChange(of: state.query) {
            state.selectedIndex = 0
        }
    }

    private struct PreviewContent {
        let title: String
        let typeLabel: String
        let icon: String
        let color: Color
        let body: String
    }

    private var selectedPreview: PreviewContent? {
        let items = state.allFlatItems
        guard items.indices.contains(state.selectedIndex),
              case let .workspaceItem(ws) = items[state.selectedIndex] else { return nil }
        switch ws.type {
        case .note:
            guard let note = notes.first(where: { $0.id == ws.id }) else { return nil }
            let body = note.content.isEmpty ? "(empty note)" : String(note.content.prefix(300))
            return PreviewContent(title: ws.title, typeLabel: "Note", icon: "doc.text", color: DS.Colors.accent, body: body)
        case .task:
            guard let task = tasks.first(where: { $0.id == ws.id }) else { return nil }
            var parts = ["Status: \(task.status.rawValue)"]
            if let due = task.dueDate { parts.append("Due: \(due.shortFormatted)") }
            if task.priority != .none { parts.append("Priority: \(task.priority.rawValue)") }
            if !task.detail.isEmpty { parts.append("\n\(task.detail.prefix(200))") }
            return PreviewContent(title: ws.title, typeLabel: "Task", icon: task.status.icon, color: DS.Colors.success, body: parts.joined(separator: "\n"))
        case .project:
            guard let project = projects.first(where: { $0.id == ws.id }) else { return nil }
            let body = "\(project.openTaskCount) open tasks · \(project.notes.count) notes\n\(project.tasks.count(where: { $0.status == .done })) done"
            return PreviewContent(title: ws.title, typeLabel: "Project", icon: "folder", color: DS.Colors.warning, body: body)
        case .knowledge:
            return PreviewContent(title: ws.title, typeLabel: "Knowledge", icon: "brain", color: DS.Colors.knowledge, body: ws.subtitle ?? "")
        }
    }

    private var recentNotes: [Note] {
        notes.filter { !$0.isArchived }.sorted(by: { (a: Note, b: Note) in a.modifiedAt > b.modifiedAt }).prefix(3).map(\.self)
    }

    private var recentTasks: [TaskItem] {
        tasks.filter { (t: TaskItem) in t.status != .done && !t.isArchived }
            .sorted(by: { (a: TaskItem, b: TaskItem) in a.createdAt > b.createdAt })
            .prefix(2).map(\.self)
    }

    @ViewBuilder
    private var recentSection: some View {
        if !recentNotes.isEmpty || !recentTasks.isEmpty {
            Text("RECENT")
                .font(DS.Font.micro)
                .fontWeight(.bold)
                .foregroundStyle(DS.Colors.textTertiary)
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.md)
                .padding(.bottom, DS.Spacing.xs)
            ForEach(recentNotes) { note in
                PaletteItemRow(
                    item: .workspaceItem(WorkspaceSearchItem(
                        id: note.id,
                        title: note.title.isEmpty ? "Untitled" : note.title,
                        subtitle: note.firstLine,
                        icon: "doc.text",
                        type: .note,
                        isArchived: note.isArchived,
                        action: {}
                    )),
                    isSelected: false
                )
                .pointerOnHover()
                .onTapGesture { appState.navigateToNote(note.id); dismiss() }
            }
            ForEach(recentTasks) { task in
                PaletteItemRow(
                    item: .workspaceItem(WorkspaceSearchItem(
                        id: task.id,
                        title: task.title.isEmpty ? "Untitled" : task.title,
                        subtitle: task.status.rawValue,
                        icon: task.status.icon,
                        type: .task,
                        isArchived: task.isArchived,
                        action: {}
                    )),
                    isSelected: false
                )
                .pointerOnHover()
                .onTapGesture { appState.navigateToTask(task.id); dismiss() }
            }
        }
    }

    private func prefixLabel(_ prefix: String) -> String {
        switch prefix {
        case ">": "Commands"
        case "#": "Notes"
        case "@": "Tasks"
        case "%": "Knowledge"
        default: prefix
        }
    }

    private func placeholderText(_ prefix: String?) -> String {
        switch prefix {
        case ">": "Search commands..."
        case "#": "Search notes..."
        case "@": "Search tasks..."
        case "%": "Search knowledge..."
        default: "Search or type > # @ %"
        }
    }

    private func dismiss() {
        appState.toggleCommandPalette()
    }

    private func updateWorkspaceItems() {
        var items: [WorkspaceSearchItem] = []

        for note in notes.prefix(50) {
            items.append(WorkspaceSearchItem(
                id: note.id,
                title: note.title.isEmpty ? "Untitled" : note.title,
                subtitle: note.firstLine,
                icon: "doc.text",
                type: .note,
                isArchived: note.isArchived,
                action: { [note] in appState.navigateToNote(note.id) }
            ))
        }

        for task in tasks.prefix(50) {
            items.append(WorkspaceSearchItem(
                id: task.id,
                title: task.title.isEmpty ? "Untitled" : task.title,
                subtitle: "[\(task.status.rawValue)] \(task.detail.prefix(60))",
                icon: task.status.icon,
                type: .task,
                isArchived: task.isArchived,
                action: { [task] in appState.navigateToTask(task.id) }
            ))
        }

        for project in projects {
            items.append(WorkspaceSearchItem(
                id: project.id,
                title: project.name,
                subtitle: "\(project.isArchived ? project.tasks.count : project.openTaskCount) tasks · \(project.notes.count) notes",
                icon: "folder",
                type: .project,
                isArchived: project.isArchived,
                action: { [project] in appState.navigateToProject(project.id) }
            ))
        }

        let knowledgeResults = KnowledgeService.shared.search("")
        for entry in knowledgeResults.prefix(20) {
            items.append(WorkspaceSearchItem(
                id: UUID(),
                title: entry.title,
                subtitle: String(entry.content.prefix(80)),
                icon: "brain",
                type: .knowledge,
                isArchived: false,
                action: { appState.navigateToContext() }
            ))
        }

        state.workspaceItems = items
    }
}

// MARK: - Palette Item Row

private struct PaletteItemRow: View {
    let item: PaletteItem
    let isSelected: Bool
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: itemIcon)
                .font(.system(size: DS.IconSize.sm, weight: .medium))
                .frame(width: DS.IconSize.xl)
                .foregroundStyle(isSelected ? DS.Colors.onAccent : iconColor)

            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(DS.Font.body)
                    .foregroundStyle(isSelected ? DS.Colors.onAccent : DS.Colors.textPrimary)
                    .lineLimit(1)

                if let subtitle = itemSubtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(DS.Font.small)
                        .foregroundStyle(isSelected ? DS.Colors.onAccent.opacity(0.6) : DS.Colors.textTertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if item.isArchived {
                Image(systemName: "archivebox")
                    .font(.system(size: DS.IconSize.xs, weight: .medium))
                    .foregroundStyle(isSelected ? DS.Colors.onAccent.opacity(0.6) : DS.Colors.textTertiary)
            }

            if let shortcut = itemShortcut {
                Text(shortcut)
                    .font(.system(size: DS.IconSize.sm, weight: .medium, design: .rounded))
                    .foregroundStyle(isSelected ? DS.Colors.onAccent.opacity(0.7) : DS.Colors.textTertiary)
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, 3)
                    .background(
                        isSelected ? AnyShapeStyle(DS.Colors.onAccent.opacity(0.15)) : AnyShapeStyle(DS.Colors.border),
                        in: RoundedRectangle(cornerRadius: DS.Radius.sm)
                    )
            }

            if let section = itemSection {
                Text(section)
                    .font(DS.Font.small)
                    .foregroundStyle(isSelected ? DS.Colors.onAccent.opacity(0.5) : DS.Colors.textTertiary)
            }
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
        .background(
            isSelected
                ? AnyShapeStyle(LinearGradient(colors: [DS.Colors.accent, DS.Colors.accent.opacity(0.8)], startPoint: .leading, endPoint: .trailing))
                : isHovered ? AnyShapeStyle(DS.Colors.fillSecondary) : AnyShapeStyle(Color.clear),
            in: RoundedRectangle(cornerRadius: DS.Radius.sm)
        )
        .contentShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
        .padding(.horizontal, DS.Spacing.sm)
        .onHover { isHovered = $0 }
        .pointerOnHover()
    }

    private var itemIcon: String {
        switch item {
        case let .command(c): c.icon
        case let .workspaceItem(w): w.icon
        }
    }

    private var iconColor: Color {
        switch item {
        case .command: DS.Colors.textSecondary
        case let .workspaceItem(w):
            switch w.type {
            case .note: DS.Colors.accent
            case .task: DS.Colors.success
            case .project: DS.Colors.warning
            case .knowledge: DS.Colors.knowledge
            }
        }
    }

    private var itemSubtitle: String? {
        switch item {
        case .command: nil
        case let .workspaceItem(w): w.subtitle
        }
    }

    private var itemShortcut: String? {
        switch item {
        case let .command(c): c.shortcut
        case .workspaceItem: nil
        }
    }

    private var itemSection: String? {
        switch item {
        case let .command(c): c.section
        case .workspaceItem: nil
        }
    }
}

// MARK: - Key Hint

private struct KeyHint: View {
    let text: String
    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.system(size: DS.IconSize.xs, weight: .medium, design: .rounded))
            .padding(.horizontal, DS.Spacing.xs)
            .padding(.vertical, DS.Spacing.xxs)
            .background(DS.Colors.border, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
    }
}
