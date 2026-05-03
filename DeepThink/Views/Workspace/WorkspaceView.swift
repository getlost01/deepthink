import SwiftUI
import SwiftData

struct WorkspaceView: View {
    @Environment(AppState.self) private var appState
    @Query private var allNotes: [Note]
    @Query private var allTasks: [TaskItem]
    @Query private var allProjects: [Project]

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
                DSHelpButton(text: SidebarSection.workspace.helpText)
            }

            Divider()

            switch appState.workspaceTab {
            case .overview:
                WorkspaceOverviewView()
            case .projects:
                projectsContent
            case .notes:
                AllNotesView()
            case .tasks:
                AllTasksView()
            }
        }
    }

    // MARK: - Projects

    @ViewBuilder
    private var projectsContent: some View {
        ResizableSplitView(minLeftWidth: 240, minRightWidth: 400) {
            ProjectListView()
                .background(DS.Colors.surface)
        } right: {
            if let project = selectedProject {
                ProjectDetailView(project: project)
                    .id(project.id)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                DSEmptyState(
                    icon: "folder",
                    title: "Select a Project",
                    subtitle: "Pick a project from the list to see its notes and tasks, or create a new one with the + button."
                )
            }
        }
    }
}
