import SwiftUI
import SwiftData

struct ProjectDetailView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Bindable var project: Project
    @Query private var allTasks: [TaskItem]
    @Query private var allNotes: [Note]

    private var selectedTask: TaskItem? {
        guard case .taskDetail(let id) = appState.projectDetailMode else { return nil }
        return allTasks.first { $0.id == id }
    }

    private var selectedNote: Note? {
        guard case .noteDetail(let id) = appState.projectDetailMode else { return nil }
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

    @ViewBuilder
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
                }

                TextField("Describe what this project is about...", text: $project.summary, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(DS.Font.body)
                    .foregroundStyle(DS.Colors.textSecondary)
                    .lineLimit(3)

                if project.totalStoryPoints > 0 {
                    let progress = Double(project.completedStoryPoints) / Double(project.totalStoryPoints)
                    HStack(spacing: DS.Spacing.md) {
                        ProgressView(value: progress)
                            .tint(DS.Colors.accent)
                            .frame(maxWidth: 200)
                        Text("\(Int(progress * 100))%")
                            .font(DS.Font.caption)
                            .foregroundStyle(DS.Colors.textTertiary)
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.vertical, DS.Spacing.lg)

            Divider()

            // Split pane: Tasks top, Notes bottom
            GeometryReader { geo in
                let totalHeight = geo.size.height
                let handleHeight: CGFloat = 8
                let available = totalHeight - handleHeight
                let topHeight = max(available * splitRatio, available * minPaneRatio)
                let bottomHeight = available - topHeight

                VStack(spacing: 0) {
                    tasksPane
                        .frame(height: topHeight)
                        .clipped()

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
                        .clipped()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onChange(of: project.name) { project.modifiedAt = Date() }
        .onChange(of: project.summary) { project.modifiedAt = Date() }
        .onAppear { appState.currentProjectName = project.name }
        .onDisappear { appState.currentProjectName = nil }
    }

    // MARK: - Tasks Pane

    @ViewBuilder
    private var tasksPane: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Tasks")
                    .font(DS.Font.small)
                    .foregroundStyle(DS.Colors.textTertiary)
                    .textCase(.uppercase)

                if !project.tasks.isEmpty {
                    DSPill(text: "\(project.openTaskCount) open", color: DS.Colors.accent)
                }

                Spacer()

                DSToolbarButton(icon: "plus", color: DS.Colors.accent, size: DS.IconSize.sm) {
                    createTaskInProject()
                }
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.vertical, DS.Spacing.sm)

            Divider()

            if project.tasks.isEmpty {
                DSEmptyState(
                    icon: "checklist",
                    title: "No tasks yet",
                    subtitle: "Break this project into smaller steps you can check off",
                    action: createTaskInProject,
                    actionTitle: "Add Task"
                )
            } else {
                ScrollView {
                    VStack(spacing: 1) {
                        ForEach(project.tasks.sorted(by: { $0.status.sortOrder < $1.status.sortOrder })) { task in
                            ProjectTaskRow(task: task) {
                                withAnimation(DS.Animation.standard) {
                                    appState.navigateToTaskInProject(task.id)
                                }
                            }
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

    @ViewBuilder
    private var notesPane: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Notes")
                    .font(DS.Font.small)
                    .foregroundStyle(DS.Colors.textTertiary)
                    .textCase(.uppercase)

                if !project.notes.isEmpty {
                    DSPill(text: "\(project.notes.count)", color: DS.Colors.warning)
                }

                Spacer()

                DSToolbarButton(icon: "plus", color: DS.Colors.accent, size: DS.IconSize.sm) {
                    createNoteInProject()
                }
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.vertical, DS.Spacing.sm)

            Divider()

            if project.notes.isEmpty {
                DSEmptyState(
                    icon: "doc.text",
                    title: "No notes yet",
                    subtitle: "Write down ideas, plans, or meeting notes for this project",
                    action: createNoteInProject,
                    actionTitle: "Add Note"
                )
            } else {
                ScrollView {
                    VStack(spacing: 1) {
                        ForEach(project.notes.sorted(by: { $0.modifiedAt > $1.modifiedAt })) { note in
                            ProjectNoteRow(note: note) {
                                withAnimation(DS.Animation.standard) {
                                    appState.navigateToNoteInProject(note.id)
                                }
                            }
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
        let task = TaskItem(title: "New Task")
        task.project = project
        modelContext.insert(task)
        appState.navigateToTaskInProject(task.id)
    }

    private func createNoteInProject() {
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
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(DS.Colors.textTertiary)
                    .opacity(isHovered ? 1 : 0)
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.sm + 2)
            .background(isHovered ? DS.Colors.fillSecondary : DS.Colors.surface)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plainPointer)
        .onHover { isHovered = $0 }
        .animation(DS.Animation.quick, value: isHovered)
    }
}

// MARK: - Note Row

private struct ProjectNoteRow: View {
    let note: Note
    let action: () -> Void
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
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(DS.Colors.textTertiary)
                    .opacity(isHovered ? 1 : 0)
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.sm + 2)
            .background(isHovered ? DS.Colors.fillSecondary : DS.Colors.surface)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plainPointer)
        .onHover { isHovered = $0 }
        .animation(DS.Animation.quick, value: isHovered)
    }
}
