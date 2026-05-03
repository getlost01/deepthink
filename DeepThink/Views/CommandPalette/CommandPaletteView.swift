import SwiftUI
import SwiftData

struct CommandPaletteView: View {
    @Environment(AppState.self) private var appState
    @Environment(CommandPaletteState.self) private var state
    @Query private var notes: [Note]
    @Query private var tasks: [TaskItem]
    @Query(filter: #Predicate<Project> { !$0.isArchived }) private var projects: [Project]

    var body: some View {
        @Bindable var state = state

        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            VStack(spacing: 0) {
                HStack(spacing: DS.Spacing.md) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14))
                        .foregroundStyle(DS.Colors.textTertiary)

                    TextField("Search commands, notes, tasks...", text: $state.query)
                        .textFieldStyle(.plain)
                        .font(.system(size: 16))
                        .onSubmit {
                            if state.executeSelected() { dismiss() }
                        }

                    if !state.query.isEmpty {
                        Button {
                            state.query = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(DS.Colors.textTertiary)
                        }
                        .buttonStyle(.plainPointer)
                    }
                }
                .padding(DS.Spacing.lg)

                Divider().opacity(0.5)

                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            let sections = state.sections
                            let flatItems = state.allFlatItems
                            var runningIndex = 0

                            ForEach(sections) { section in
                                Text(section.title.uppercased())
                                    .font(.system(size: 9, weight: .bold))
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
                                            case .command(let cmd): cmd.action()
                                            case .workspaceItem(let ws): ws.action()
                                            }
                                            dismiss()
                                        }
                                }
                            }

                            if flatItems.isEmpty && !state.query.isEmpty {
                                VStack(spacing: DS.Spacing.sm) {
                                    Image(systemName: "magnifyingglass")
                                        .font(.system(size: 20, weight: .light))
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
                    .frame(maxHeight: 400)
                    .onChange(of: state.selectedIndex) { _, newValue in
                        let items = state.allFlatItems
                        if items.indices.contains(newValue) {
                            proxy.scrollTo(items[newValue].id, anchor: .center)
                        }
                    }
                }

                Divider().opacity(0.5)

                HStack(spacing: DS.Spacing.lg) {
                    HStack(spacing: DS.Spacing.xs) {
                        KeyHint("↑↓")
                        Text("navigate")
                    }
                    HStack(spacing: DS.Spacing.xs) {
                        KeyHint("↵")
                        Text("select")
                    }
                    HStack(spacing: DS.Spacing.xs) {
                        KeyHint("esc")
                        Text("close")
                    }
                    Spacer()
                    if !state.query.isEmpty {
                        let count = state.allFlatItems.count
                        Text("\(count) result\(count == 1 ? "" : "s")")
                            .foregroundStyle(DS.Colors.textTertiary)
                    }
                }
                .font(DS.Font.small)
                .foregroundStyle(DS.Colors.textTertiary)
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.sm)
            }
            .frame(width: 560)
            .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.lg))
            .overlay {
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.25), radius: 30, y: 10)
            .padding(.top, 80)
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .onKeyPress(.upArrow) { state.moveUp(); return .handled }
        .onKeyPress(.downArrow) { state.moveDown(); return .handled }
        .onKeyPress(.escape) { dismiss(); return .handled }
        .onAppear {
            state.reset()
            updateWorkspaceItems()
        }
        .onChange(of: state.query) {
            state.selectedIndex = 0
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
                action: { [task] in appState.navigateToTask(task.id) }
            ))
        }

        for project in projects {
            items.append(WorkspaceSearchItem(
                id: project.id,
                title: project.name,
                subtitle: "\(project.openTaskCount) tasks · \(project.notes.count) notes",
                icon: "folder",
                type: .project,
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

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: itemIcon)
                .font(.system(size: 12, weight: .medium))
                .frame(width: 20)
                .foregroundStyle(isSelected ? .white : iconColor)

            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(DS.Font.body)
                    .foregroundStyle(isSelected ? .white : DS.Colors.textPrimary)
                    .lineLimit(1)

                if let subtitle = itemSubtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(DS.Font.small)
                        .foregroundStyle(isSelected ? .white.opacity(0.6) : DS.Colors.textTertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if let shortcut = itemShortcut {
                Text(shortcut)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(isSelected ? .white.opacity(0.7) : DS.Colors.textTertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        (isSelected ? AnyShapeStyle(.white.opacity(0.15)) : AnyShapeStyle(DS.Colors.border)),
                        in: RoundedRectangle(cornerRadius: 4)
                    )
            }

            if let section = itemSection {
                Text(section)
                    .font(DS.Font.small)
                    .foregroundStyle(isSelected ? .white.opacity(0.5) : DS.Colors.textTertiary)
            }
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
        .background(
            isSelected
                ? AnyShapeStyle(LinearGradient(colors: [DS.Colors.accent, DS.Colors.accent.opacity(0.8)], startPoint: .leading, endPoint: .trailing))
                : AnyShapeStyle(.clear),
            in: RoundedRectangle(cornerRadius: DS.Radius.sm)
        )
        .contentShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
        .padding(.horizontal, DS.Spacing.sm)
    }

    private var itemIcon: String {
        switch item {
        case .command(let c): c.icon
        case .workspaceItem(let w): w.icon
        }
    }

    private var iconColor: Color {
        switch item {
        case .command: DS.Colors.textSecondary
        case .workspaceItem(let w):
            switch w.type {
            case .note: DS.Colors.accent
            case .task: DS.Colors.success
            case .project: DS.Colors.warning
            case .knowledge: Color(hue: 0.75, saturation: 0.5, brightness: 0.85)
            }
        }
    }

    private var itemSubtitle: String? {
        switch item {
        case .command: nil
        case .workspaceItem(let w): w.subtitle
        }
    }

    private var itemShortcut: String? {
        switch item {
        case .command(let c): c.shortcut
        case .workspaceItem: nil
        }
    }

    private var itemSection: String? {
        switch item {
        case .command(let c): c.section
        case .workspaceItem: nil
        }
    }
}

// MARK: - Key Hint

private struct KeyHint: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .medium, design: .rounded))
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(DS.Colors.border, in: RoundedRectangle(cornerRadius: 3))
    }
}
