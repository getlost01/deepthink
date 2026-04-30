import SwiftUI
import SwiftData

struct ProjectListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Query(sort: \Project.modifiedAt, order: .reverse) private var allProjects: [Project]
    @State private var showArchived = false

    private var projects: [Project] {
        showArchived ? allProjects : allProjects.filter { !$0.isArchived }
    }

    private let columns = [GridItem(.adaptive(minimum: 220, maximum: 300), spacing: DS.Spacing.lg)]

    var body: some View {
        @Bindable var appState = appState

        ScrollView {
            if projects.isEmpty {
                DSEmptyState(
                    icon: "folder",
                    title: "No Projects",
                    subtitle: "Create a project to organize your work",
                    action: createProject,
                    actionTitle: "New Project"
                )
            } else {
                LazyVGrid(columns: columns, spacing: DS.Spacing.lg) {
                    ForEach(projects) { project in
                        ProjectCard(project: project, isSelected: appState.selectedProjectID == project.id)
                            .onTapGesture {
                                appState.selectedProjectID = project.id
                            }
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
                .padding(DS.Spacing.xl)
            }
        }
        .navigationTitle("Projects")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                HStack(spacing: DS.Spacing.sm) {
                    Button {
                        showArchived.toggle()
                    } label: {
                        Image(systemName: showArchived ? "archivebox.fill" : "archivebox")
                            .foregroundStyle(showArchived ? DS.Colors.accent : DS.Colors.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .help(showArchived ? "Hide Archived" : "Show Archived")

                    Button(action: createProject) {
                        Image(systemName: "plus")
                    }
                    .help("New Project")
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

private struct ProjectCard: View {
    let project: Project
    let isSelected: Bool

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
            }

            if !project.summary.isEmpty {
                Text(project.summary)
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Colors.textSecondary)
                    .lineLimit(2)
            }

            HStack(spacing: DS.Spacing.md) {
                Label("\(project.notes.count)", systemImage: "doc.text")
                Label("\(project.openTaskCount)", systemImage: "checklist")
            }
            .font(DS.Font.tiny)
            .foregroundStyle(DS.Colors.textTertiary)
        }
        .padding(DS.Spacing.lg)
        .background(.background, in: RoundedRectangle(cornerRadius: DS.Radius.lg))
        .overlay {
            RoundedRectangle(cornerRadius: DS.Radius.lg)
                .strokeBorder(isSelected ? Color.accentColor : DS.Colors.border, lineWidth: isSelected ? 1.5 : 0.5)
        }
    }
}
