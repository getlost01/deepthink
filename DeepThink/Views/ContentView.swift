import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(CommandPaletteState.self) private var commandPaletteState

    var body: some View {
        @Bindable var appState = appState

        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 200, ideal: 230, max: 260)
        } detail: {
            ContentRouter()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationSplitViewStyle(.balanced)
        .overlay {
            if appState.showCommandPalette {
                CommandPaletteView()
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
    }
}

struct ContentRouter: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            switch appState.selectedSection {
            case .home:
                HomeView()
            case .chat:
                AIChatView()
            case .deepSearch:
                DeepSearchView()
            case .analysis:
                AnalysisView()
            case .memory:
                MemoryView()
            case .notes:
                NoteWorkspace()
            case .tasks:
                TaskWorkspace()
            case .projects:
                ProjectContentView()
            case .tools:
                ToolsHubView()
            case .graph:
                KnowledgeGraphView()
            case .terminal:
                TerminalView()
            case nil:
                HomeView()
            }
        }
    }
}

struct NoteWorkspace: View {
    @Environment(AppState.self) private var appState
    @Query private var allNotes: [Note]

    private var selectedNote: Note? {
        guard let id = appState.selectedNoteID else { return nil }
        return allNotes.first { $0.id == id }
    }

    var body: some View {
        HStack(spacing: 0) {
            NoteListView()
                .frame(width: 250)
                .background(DS.Colors.surface)

            Divider()

            if let note = selectedNote {
                NoteEditorView(note: note)
                    .id(note.id)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                DSEmptyState(
                    icon: "doc.text",
                    title: "No note selected",
                    subtitle: "Choose a note from the list or create a new one"
                )
            }
        }
    }
}

struct TaskWorkspace: View {
    @Environment(AppState.self) private var appState
    @Query private var allTasks: [TaskItem]

    private var selectedTask: TaskItem? {
        guard let id = appState.selectedTaskID else { return nil }
        return allTasks.first { $0.id == id }
    }

    var body: some View {
        HStack(spacing: 0) {
            TaskListView()
                .frame(width: 250)
                .background(DS.Colors.surface)

            Divider()

            if let task = selectedTask {
                TaskDetailView(task: task)
                    .id(task.id)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                DSEmptyState(
                    icon: "checklist",
                    title: "No task selected",
                    subtitle: "Choose a task from the list or create a new one"
                )
            }
        }
    }
}

struct ProjectContentView: View {
    @Environment(AppState.self) private var appState
    @Query private var allProjects: [Project]

    private var selectedProject: Project? {
        guard let id = appState.selectedProjectID else { return nil }
        return allProjects.first { $0.id == id }
    }

    var body: some View {
        if let project = selectedProject {
            VStack(spacing: 0) {
                HStack {
                    Button {
                        appState.selectedProjectID = nil
                    } label: {
                        HStack(spacing: DS.Spacing.xs) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 11, weight: .semibold))
                            Text("Projects")
                                .font(DS.Font.caption)
                        }
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.vertical, DS.Spacing.md)
                .background(.bar)

                Divider()

                ProjectDetailView(project: project)
                    .id(project.id)
            }
        } else {
            ProjectListView()
        }
    }
}
