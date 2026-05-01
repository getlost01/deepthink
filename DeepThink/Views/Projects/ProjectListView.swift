import SwiftUI
import SwiftData

struct ProjectListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Query(sort: \Project.modifiedAt, order: .reverse) private var allProjects: [Project]
    @State private var searchText = ""
    @State private var showArchived = false

    private var projects: [Project] {
        var result = showArchived ? allProjects : allProjects.filter { !$0.isArchived }
        if !searchText.isEmpty {
            let lowered = searchText.lowercased()
            result = result.filter { $0.name.lowercased().contains(lowered) || $0.summary.lowercased().contains(lowered) }
        }
        return result
    }

    var body: some View {
        @Bindable var appState = appState

        VStack(spacing: 0) {
            DSPageHeader(title: "Projects") {
                DSToolbarButton(
                    icon: showArchived ? "archivebox.fill" : "archivebox",
                    color: showArchived ? DS.Colors.accent : DS.Colors.textTertiary,
                    size: DS.IconSize.md
                ) {
                    showArchived.toggle()
                }
                .help(showArchived ? "Hide Archived" : "Show Archived")

                DSToolbarButton(icon: "plus.circle.fill", color: DS.Colors.accent, size: DS.IconSize.lg) {
                    createProject()
                }
                .help("New Project (⇧⌘N)")
            }

            DSSearchField(text: $searchText, placeholder: "Search projects...")
                .padding(.horizontal, DS.Spacing.md)
                .padding(.bottom, DS.Spacing.sm)

            Divider()

            List(selection: $appState.selectedProjectID) {
                ForEach(projects) { project in
                    ProjectRow(project: project)
                        .tag(project.id)
                        .contextMenu {
                            Button(project.isArchived ? "Unarchive" : "Archive") {
                                project.isArchived.toggle()
                                project.modifiedAt = Date()
                            }
                            Divider()
                            Button("Delete", role: .destructive) {
                                if appState.selectedProjectID == project.id {
                                    appState.selectedProjectID = nil
                                }
                                modelContext.delete(project)
                            }
                        }
                }
            }
            .listStyle(.inset)
            .overlay {
                if projects.isEmpty {
                    DSEmptyState(
                        icon: "folder",
                        title: "No Projects Yet",
                        subtitle: "Projects help you organize related notes and tasks into focused workstreams",
                        action: createProject,
                        actionTitle: "New Project"
                    )
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .createNewProject)) { _ in
            createProject()
        }
    }

    private func createProject() {
        let project = Project(name: "New Project")
        modelContext.insert(project)
        appState.selectedProjectID = project.id
    }
}

private struct ProjectRow: View {
    let project: Project

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.sm) {
                Circle()
                    .fill(Color(hex: project.color))
                    .frame(width: 8, height: 8)
                Text(project.name)
                    .font(DS.Font.body)
                    .fontWeight(.medium)
                    .lineLimit(1)
                if project.isArchived {
                    DSPill(text: "Archived", color: .secondary)
                }
            }
            HStack(spacing: 0) {
                if !project.summary.isEmpty {
                    Text(project.summary)
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Colors.textSecondary)
                        .lineLimit(1)
                }
                Spacer()
                HStack(spacing: DS.Spacing.md) {
                    Label("\(project.notes.count)", systemImage: "doc.text")
                    Label("\(project.openTaskCount)", systemImage: "checklist")
                }
                .font(DS.Font.tiny)
                .foregroundStyle(DS.Colors.textTertiary)
            }
        }
        .padding(.vertical, DS.Spacing.xs)
    }
}
