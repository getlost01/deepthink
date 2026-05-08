import SwiftData
import SwiftUI

struct ProjectDetailView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Bindable var project: Project
    @Query private var allTasks: [TaskItem]
    @Query private var allNotes: [Note]

    private var selectedTask: TaskItem? {
        guard case let .taskDetail(id) = appState.projectDetailMode else { return nil }
        return allTasks.first { $0.id == id }
    }

    private var selectedNote: Note? {
        guard case let .noteDetail(id) = appState.projectDetailMode else { return nil }
        return allNotes.first { $0.id == id }
    }

    var body: some View {
        switch appState.projectDetailMode {
        case .overview:
            projectOverview
        case .taskDetail:
            if let task = selectedTask {
                VStack(spacing: 0) {
                    backBar
                    Divider()
                    TaskDetailView(task: task)
                        .id(task.id)
                }
            }
        case .noteDetail:
            if let note = selectedNote {
                VStack(spacing: 0) {
                    backBar
                    Divider()
                    NoteEditorView(note: note)
                        .id(note.id)
                }
            }
        }
    }

    private var backBar: some View {
        HStack(spacing: DS.Spacing.sm) {
            Button {
                withAnimation(DS.Animation.standard) {
                    appState.backToProjectOverview()
                }
            } label: {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: DS.IconSize.sm, weight: .medium))
                    Text(project.name)
                        .font(DS.Font.body)
                }
                .foregroundStyle(DS.Colors.accent)
            }
            .buttonStyle(.plainPointer)

            Spacer()
        }
        .frame(height: DS.Layout.toolbarHeight)
        .padding(.horizontal, DS.Spacing.xl)
    }

    // MARK: - Overview

    @State private var splitRatio: CGFloat = 0.5
    private let minPaneRatio: CGFloat = 0.2
    @State private var showArchivedTasks = false
    @State private var showArchivedNotes = false
    @State private var descriptionPreview = false

    private var projectOverview: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                HStack(spacing: DS.Spacing.md) {
                    Circle()
                        .fill(Color(hex: project.color))
                        .frame(width: 14, height: 14)

                    TextField("Give your project a name", text: $project.name)
                        .textFieldStyle(.plain)
                        .font(DS.Font.title)
                        .disabled(project.isArchived)
                }

                HStack(alignment: .top, spacing: DS.Spacing.xs) {
                    if descriptionPreview {
                        Group {
                            if let attributed = try? AttributedString(
                                markdown: project.summary,
                                options: .init(interpretedSyntax: .full)
                            ) {
                                Text(attributed)
                            } else {
                                Text(project.summary)
                            }
                        }
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Colors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .environment(\.openURL, OpenURLAction { url in
                            if url.scheme == "deepthink" {
                                appState.handleDeepLink(url)
                                return .handled
                            }
                            return .systemAction
                        })
                    } else {
                        TextField("Describe what this project is about...", text: $project.summary, axis: .vertical)
                            .textFieldStyle(.plain)
                            .font(DS.Font.caption)
                            .foregroundStyle(DS.Colors.textSecondary)
                            .lineLimit(3)
                            .disabled(project.isArchived)
                    }

                    if !project.summary.isEmpty || descriptionPreview {
                        Button {
                            withAnimation(DS.Animation.quick) { descriptionPreview.toggle() }
                        } label: {
                            Image(systemName: descriptionPreview ? "pencil" : "eye")
                                .font(.system(size: DS.IconSize.xs))
                                .foregroundStyle(DS.Colors.textTertiary)
                        }
                        .buttonStyle(.plainPointer)
                        .help(descriptionPreview ? "Edit description" : "Preview links")
                    }
                }

                if !project.tasks.isEmpty {
                    let total = project.tasks.count
                    let done = project.completedTaskCount
                    let progress = Double(done) / Double(total)

                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        HStack(spacing: DS.Spacing.md) {
                            ProgressView(value: progress)
                                .tint(Color(hex: project.color))

                            Text("\(done)/\(total) tasks")
                                .font(DS.Font.caption)
                                .foregroundStyle(DS.Colors.textTertiary)

                            if project.totalStoryPoints > 0 {
                                Text("·")
                                    .foregroundStyle(DS.Colors.textTertiary)
                                Text("\(project.completedStoryPoints)/\(project.totalStoryPoints) pts")
                                    .font(DS.Font.caption)
                                    .foregroundStyle(DS.Colors.textTertiary)
                            }
                        }

                        HStack(spacing: DS.Spacing.md) {
                            ForEach(TaskStatus.allCases) { status in
                                let count = project.tasks.count(where: { $0.status == status })
                                if count > 0 {
                                    HStack(spacing: DS.Spacing.xs) {
                                        Circle()
                                            .fill(status.color)
                                            .frame(width: 6, height: 6)
                                        Text("\(count) \(status.rawValue)")
                                            .font(DS.Font.small)
                                            .foregroundStyle(DS.Colors.textTertiary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.vertical, DS.Spacing.lg)

            Divider()

            if project.isArchived {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "archivebox.fill")
                        .font(.system(size: DS.IconSize.xs, weight: .medium))
                    Text("Archived — unarchive to edit")
                        .font(DS.Font.caption)
                        .fontWeight(.medium)
                    Spacer()
                    Button("Unarchive") {
                        project.isArchived = false
                        project.modifiedAt = Date()
                    }
                    .font(DS.Font.caption)
                    .buttonStyle(.plainPointer)
                    .foregroundStyle(DS.Colors.accent)
                }
                .foregroundStyle(DS.Colors.textSecondary)
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.vertical, DS.Spacing.sm)
                .background(DS.Colors.fillSecondary)
                .overlay(Divider(), alignment: .bottom)
            }

            // Split pane: Tasks top, Notes bottom
            GeometryReader { geo in
                let totalHeight = geo.size.height
                let handleHeight: CGFloat = 8
                let available = totalHeight - handleHeight
                let clampedRatio = min(max(splitRatio, minPaneRatio), 1 - minPaneRatio)
                let topHeight = available * clampedRatio
                let bottomHeight = available - topHeight

                VStack(spacing: 0) {
                    tasksPane
                        .frame(height: topHeight)

                    DSSplitHandle(axis: .horizontal)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    let newRatio = (topHeight + value.translation.height) / available
                                    splitRatio = min(max(newRatio, minPaneRatio), 1 - minPaneRatio)
                                }
                        )

                    notesPane
                        .frame(height: bottomHeight)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onChange(of: project.name) { project.modifiedAt = Date() }
        .onChange(of: project.summary) { project.modifiedAt = Date() }
        .onAppear {
            appState.currentProjectName = project.name
            if project.isArchived {
                showArchivedTasks = true
                showArchivedNotes = true
            }
        }
        .onChange(of: project.id) {
            showArchivedTasks = project.isArchived
            showArchivedNotes = project.isArchived
            descriptionPreview = false
        }
        .onDisappear { appState.currentProjectName = nil }
    }

    // MARK: - Tasks Pane

    private var visibleTasks: [TaskItem] {
        project.tasks
            .filter { showArchivedTasks ? $0.isArchived : !$0.isArchived }
            .sorted(by: { $0.status.sortOrder < $1.status.sortOrder })
    }

    private var visibleNotes: [Note] {
        project.notes
            .filter { showArchivedNotes ? $0.isArchived : !$0.isArchived }
            .sorted(by: { $0.modifiedAt > $1.modifiedAt })
    }

    private var tasksPane: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Tasks")
                    .font(DS.Font.small)
                    .foregroundStyle(DS.Colors.textTertiary)
                    .textCase(.uppercase)

                if !visibleTasks.isEmpty {
                    DSPill(
                        text: showArchivedTasks ? "\(visibleTasks.count) archived" : "\(project.openTaskCount) open",
                        color: showArchivedTasks ? DS.Colors.textSecondary : DS.Colors.accent
                    )
                }

                Spacer()

                HStack(spacing: DS.Spacing.xs) {
                    DSArchiveButton(isOn: showArchivedTasks, count: project.tasks.count(where: { $0.isArchived })) { showArchivedTasks.toggle() }
                    if !project.isArchived { DSAddButton { createTaskInProject() } }
                }
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.vertical, DS.Spacing.sm)

            Divider()

            if visibleTasks.isEmpty {
                ScrollView {
                    DSEmptyState(
                        icon: "checklist",
                        title: showArchivedTasks ? "No archived tasks" : "No tasks yet",
                        subtitle: showArchivedTasks ? "Archived tasks will appear here." : "Break this project into smaller steps you can check off",
                        action: showArchivedTasks ? nil : createTaskInProject,
                        actionTitle: "Add Task"
                    )
                    .frame(minHeight: 200)
                }
            } else {
                ScrollView {
                    VStack(spacing: 1) {
                        ForEach(visibleTasks) { task in
                            ProjectTaskRow(task: task, action: {
                                withAnimation(DS.Animation.standard) {
                                    appState.navigateToTaskInProject(task.id)
                                }
                            }, onDelete: {
                                modelContext.delete(task)
                            })
                        }
                    }
                    .background(DS.Colors.border)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.md)
                            .strokeBorder(DS.Colors.border, lineWidth: 1)
                    )
                    .padding(.horizontal, DS.Spacing.xl)
                    .padding(.vertical, DS.Spacing.sm)
                }
            }
        }
    }

    // MARK: - Notes Pane

    private var notesPane: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Notes")
                    .font(DS.Font.small)
                    .foregroundStyle(DS.Colors.textTertiary)
                    .textCase(.uppercase)

                if !visibleNotes.isEmpty {
                    DSPill(
                        text: showArchivedNotes ? "\(visibleNotes.count) archived" : "\(visibleNotes.count)",
                        color: showArchivedNotes ? DS.Colors.textSecondary : DS.Colors.warning
                    )
                }

                Spacer()

                HStack(spacing: DS.Spacing.xs) {
                    DSArchiveButton(isOn: showArchivedNotes, count: project.notes.count(where: { $0.isArchived })) { showArchivedNotes.toggle() }
                    if !project.isArchived { DSAddButton { createNoteInProject() } }
                }
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.vertical, DS.Spacing.sm)

            Divider()

            if visibleNotes.isEmpty {
                ScrollView {
                    DSEmptyState(
                        icon: "doc.text",
                        title: showArchivedNotes ? "No archived notes" : "No notes yet",
                        subtitle: showArchivedNotes ? "Archived notes will appear here." : "Write down ideas, plans, or meeting notes for this project",
                        action: showArchivedNotes ? nil : createNoteInProject,
                        actionTitle: "Add Note"
                    )
                    .frame(minHeight: 200)
                }
            } else {
                ScrollView {
                    VStack(spacing: 1) {
                        ForEach(visibleNotes) { note in
                            ProjectNoteRow(note: note, action: {
                                withAnimation(DS.Animation.standard) {
                                    appState.navigateToNoteInProject(note.id)
                                }
                            }, onDelete: {
                                modelContext.delete(note)
                            })
                        }
                    }
                    .background(DS.Colors.border)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.md)
                            .strokeBorder(DS.Colors.border, lineWidth: 1)
                    )
                    .padding(.horizontal, DS.Spacing.xl)
                    .padding(.vertical, DS.Spacing.sm)
                }
            }
        }
    }

    private func createTaskInProject() {
        showArchivedTasks = false
        let task = TaskItem(title: "New Task")
        task.project = project
        modelContext.insert(task)
        appState.navigateToTaskInProject(task.id)
    }

    private func createNoteInProject() {
        showArchivedNotes = false
        let note = Note(title: "Untitled Note")
        note.project = project
        modelContext.insert(note)
        appState.navigateToNoteInProject(note.id)
    }
}

// MARK: - Task Row

private struct ProjectTaskRow: View {
    let task: TaskItem
    let action: () -> Void
    var onDelete: (() -> Void)?
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: task.status.icon)
                    .font(.system(size: DS.IconSize.sm, weight: .medium))
                    .foregroundStyle(task.status.color)
                    .frame(width: 18)

                Text(task.title)
                    .font(DS.Font.body)
                    .lineLimit(1)
                    .foregroundStyle(task.status == .done ? DS.Colors.textTertiary : DS.Colors.textPrimary)

                if !task.subtasks.isEmpty {
                    let done = task.subtasks.count(where: { $0.status == .done })
                    HStack(spacing: DS.Spacing.xxs) {
                        Image(systemName: "checklist")
                            .font(.system(size: DS.IconSize.xs))
                        Text("\(done)/\(task.subtasks.count)")
                            .font(DS.Font.small)
                    }
                    .foregroundStyle(done == task.subtasks.count ? DS.Colors.success : DS.Colors.textTertiary)
                }

                Spacer()

                if task.priority != .none {
                    Image(systemName: task.priority.icon)
                        .font(.system(size: DS.IconSize.sm))
                        .foregroundStyle(task.priority.color)
                }

                if let due = task.dueDate {
                    Text(due.shortFormatted)
                        .font(DS.Font.small)
                        .foregroundStyle(task.isOverdue ? DS.Colors.danger : DS.Colors.textTertiary)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: DS.IconSize.xs, weight: .semibold))
                    .foregroundStyle(DS.Colors.textTertiary)
                    .opacity(isHovered ? 1 : 0)
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)
            .background(isHovered ? DS.Colors.fillSecondary : DS.Colors.surface)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plainPointer)
        .onHover { isHovered = $0 }
        .animation(DS.Animation.quick, value: isHovered)
        .contextMenu {
            Button(action: action) {
                Label("Open", systemImage: "doc.text")
            }
            Divider()
            ForEach(TaskStatus.allCases) { newStatus in
                Button("Mark as \(newStatus.rawValue)") {
                    task.status = newStatus
                    task.modifiedAt = Date()
                }
            }
            Divider()
            Button(task.isArchived ? "Unarchive" : "Archive") {
                if task.isArchived {
                    task.isArchived = false
                    task.manuallyArchived = false
                } else {
                    task.isArchived = true
                    task.manuallyArchived = true
                }
                task.modifiedAt = Date()
            }
            if let onDelete {
                Divider()
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }
}

// MARK: - Note Row

private struct ProjectNoteRow: View {
    @Environment(\.modelContext) private var modelContext
    let note: Note
    let action: () -> Void
    var onDelete: (() -> Void)?
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: note.isPinned ? "pin.fill" : "doc.text")
                    .font(.system(size: DS.IconSize.sm, weight: .medium))
                    .foregroundStyle(note.isPinned ? DS.Colors.warning : DS.Colors.textTertiary)
                    .frame(width: 18)

                Text(note.title.isEmpty ? "Untitled" : note.title)
                    .font(DS.Font.body)
                    .lineLimit(1)
                    .foregroundStyle(DS.Colors.textPrimary)

                Spacer()

                Text(note.modifiedAt.relativeFormatted)
                    .font(DS.Font.small)
                    .foregroundStyle(DS.Colors.textTertiary)

                Image(systemName: "chevron.right")
                    .font(.system(size: DS.IconSize.xs, weight: .semibold))
                    .foregroundStyle(DS.Colors.textTertiary)
                    .opacity(isHovered ? 1 : 0)
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)
            .background(isHovered ? DS.Colors.fillSecondary : DS.Colors.surface)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plainPointer)
        .onHover { isHovered = $0 }
        .animation(DS.Animation.quick, value: isHovered)
        .contextMenu {
            Button(action: action) {
                Label("Open", systemImage: "doc.text")
            }
            Divider()
            Button(note.isPinned ? "Unpin" : "Pin") {
                note.isPinned.toggle()
                note.modifiedAt = Date()
                try? modelContext.save()
            }
            Button(note.isArchived ? "Unarchive" : "Archive") {
                note.isArchived.toggle()
                note.modifiedAt = Date()
                try? modelContext.save()
            }
            if let onDelete {
                Divider()
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }
}
