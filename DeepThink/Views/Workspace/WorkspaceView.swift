import SwiftUI
import SwiftData

struct WorkspaceView: View {
    @Environment(AppState.self) private var appState
    @Query private var allNotes: [Note]
    @Query private var allTasks: [TaskItem]
    @Query private var allProjects: [Project]

    private var selectedNote: Note? {
        guard let id = appState.selectedNoteID else { return nil }
        return allNotes.first { $0.id == id }
    }

    private var selectedTask: TaskItem? {
        guard let id = appState.selectedTaskID else { return nil }
        return allTasks.first { $0.id == id }
    }

    private var selectedProject: Project? {
        guard let id = appState.selectedProjectID else { return nil }
        return allProjects.first { $0.id == id }
    }

    var body: some View {
        @Bindable var appState = appState

        VStack(spacing: 0) {
            DSToolbarBar {
                ForEach(WorkspaceTab.allCases) { tab in
                    DSTabButton(
                        title: tab.rawValue,
                        icon: tab.icon,
                        isSelected: appState.workspaceTab == tab,
                        action: { appState.workspaceTab = tab }
                    )
                }
                Spacer()
            }

            Divider()

            switch appState.workspaceTab {
            case .notes:
                notesContent
            case .tasks:
                tasksContent
            case .projects:
                projectsContent
            }
        }
    }

    // MARK: - Notes

    @ViewBuilder
    private var notesContent: some View {
        HStack(spacing: 0) {
            NoteListView()
                .frame(width: DS.Layout.listPanelWidth)

            Divider()

            if let note = selectedNote {
                NoteEditorView(note: note)
                    .id(note.id)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                DSEmptyState(
                    icon: "doc.text",
                    title: "No note selected",
                    subtitle: "Choose a note or create a new one"
                )
            }
        }
    }

    // MARK: - Tasks

    @ViewBuilder
    private var tasksContent: some View {
        HStack(spacing: 0) {
            TaskListView()
                .frame(width: DS.Layout.listPanelWidth)

            Divider()

            if let task = selectedTask {
                TaskDetailView(task: task)
                    .id(task.id)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                DSEmptyState(
                    icon: "checklist",
                    title: "No task selected",
                    subtitle: "Choose a task or create a new one"
                )
            }
        }
    }

    // MARK: - Projects

    @ViewBuilder
    private var projectsContent: some View {
        HStack(spacing: 0) {
            ProjectListView()
                .frame(width: DS.Layout.listPanelWidth)

            Divider()

            if let project = selectedProject {
                ProjectDetailView(project: project)
                    .id(project.id)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                DSEmptyState(
                    icon: "folder",
                    title: "No project selected",
                    subtitle: "Choose a project or create a new one"
                )
            }
        }
    }
}

// MARK: - Shared Tab Button

struct DSTabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: DS.IconSize.sm))
                Text(title)
                    .font(DS.Font.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .foregroundStyle(isSelected ? DS.Colors.textPrimary : DS.Colors.textSecondary)
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .background(
                isSelected
                    ? DS.Colors.accent.opacity(0.1)
                    : (isHovered ? DS.Colors.hoverBg : .clear),
                in: RoundedRectangle(cornerRadius: DS.Radius.sm)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
