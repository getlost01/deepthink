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

    private let columns = [GridItem(.adaptive(minimum: 220, maximum: 300), spacing: 16)]

    var body: some View {
        @Bindable var appState = appState

        ScrollView {
            if projects.isEmpty {
                EmptyStateView(
                    icon: "folder",
                    title: "No Projects",
                    subtitle: "Create a project to organize your work"
                )
                .frame(maxWidth: .infinity)
                .padding(.top, 100)
            } else {
                LazyVGrid(columns: columns, spacing: 16) {
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
                .padding(20)
            }
        }
        .navigationTitle("Projects")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: createProject) {
                    Image(systemName: "folder.badge.plus")
                }
                .help("New Project")
            }
            ToolbarItem(placement: .automatic) {
                Toggle(isOn: $showArchived) {
                    Image(systemName: "archivebox")
                }
                .help("Show Archived")
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
        VStack(alignment: .leading, spacing: 12) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(hex: project.color))
                .frame(height: 4)

            Text(project.name)
                .font(.headline)
                .lineLimit(1)

            if !project.summary.isEmpty {
                Text(project.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 12) {
                Label("\(project.notes.count)", systemImage: "doc.text")
                Label("\(project.openTaskCount)", systemImage: "checklist")
                if project.totalStoryPoints > 0 {
                    Label("\(project.completedStoryPoints)/\(project.totalStoryPoints) SP", systemImage: "chart.bar")
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.background)
                .shadow(color: .black.opacity(0.08), radius: isSelected ? 8 : 4, y: 2)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 2)
        }
    }
}
