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
            }

            Divider()

            switch appState.workspaceTab {
            case .projects:
                projectsContent
            case .knowledge:
                KnowledgeGraphView()
            }
        }
    }

    // MARK: - Projects

    @ViewBuilder
    private var projectsContent: some View {
        HStack(spacing: 0) {
            ProjectListView()
                .dsListPanel()

            Divider()

            if let project = selectedProject {
                ProjectDetailView(project: project)
                    .id(project.id)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                DSEmptyState(
                    icon: "folder",
                    title: "Select a Project",
                    subtitle: "Projects group related notes and tasks together. Create one to get organized."
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
                    .font(.system(size: DS.IconSize.sm, weight: .medium))
                Text(title)
                    .font(DS.Font.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .foregroundStyle(isSelected ? DS.Colors.textPrimary : DS.Colors.textSecondary)
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .background(
                isSelected
                    ? DS.Colors.selectedBg
                    : (isHovered ? DS.Colors.hoverBg : .clear),
                in: RoundedRectangle(cornerRadius: DS.Radius.sm)
            )
        }
        .buttonStyle(.plainPointer)
        .onHover { isHovered = $0 }
        .animation(DS.Animation.quick, value: isHovered)
    }
}
