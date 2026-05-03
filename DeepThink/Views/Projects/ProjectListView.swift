import SwiftUI
import SwiftData

struct ProjectListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Query(sort: \Project.modifiedAt, order: .reverse) private var allProjects: [Project]
    @State private var searchText = ""
    @State private var debouncedSearch = ""
    @State private var searchTask: Task<Void, Never>?
    @State private var showArchived = false
    @State private var projectToDelete: Project?
    @State private var showDeleteConfirm = false

    private var projects: [Project] {
        var result = showArchived ? allProjects : allProjects.filter { !$0.isArchived }
        if !debouncedSearch.isEmpty {
            let lowered = debouncedSearch.lowercased()
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

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(projects) { project in
                        let isSelected = appState.selectedProjectID == project.id
                        Button {
                            appState.selectedProjectID = project.id
                        } label: {
                            ProjectCard(project: project)
                                .padding(.horizontal, DS.Spacing.sm)
                                .padding(.vertical, 2)
                                .background(isSelected ? DS.Colors.accentFill : .clear)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plainPointer)
                        .contextMenu {
                            Button(project.isArchived ? "Unarchive" : "Archive") {
                                project.isArchived.toggle()
                                project.modifiedAt = Date()
                            }
                            Divider()
                            Button("Delete", role: .destructive) {
                                projectToDelete = project
                                showDeleteConfirm = true
                            }
                        }
                    }
                }
            }
            .onKeyPress(.upArrow) { moveSelection(-1); return .handled }
            .onKeyPress(.downArrow) { moveSelection(1); return .handled }
            .onKeyPress(.escape) { appState.selectedProjectID = nil; return .handled }
            .overlay {
                if projects.isEmpty {
                    DSEmptyState(
                        icon: "folder",
                        title: "No Projects Yet",
                        subtitle: "Projects keep related notes and tasks together — like a folder for everything about one goal or topic.",
                        hint: "Example: \"Product Launch\", \"Home Renovation\", \"Research Paper\"",
                        action: createProject,
                        actionTitle: "New Project"
                    )
                }
            }
        }
        .onChange(of: searchText) {
            searchTask?.cancel()
            searchTask = Task {
                try? await Task.sleep(for: .milliseconds(200))
                guard !Task.isCancelled else { return }
                debouncedSearch = searchText
            }
        }
        .onChange(of: appState.selectedProjectID) {
            appState.projectDetailMode = .overview
        }
        .onReceive(NotificationCenter.default.publisher(for: .createNewProject)) { _ in
            createProject()
        }
        .confirmationDialog("Delete Project?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                if let project = projectToDelete {
                    if appState.selectedProjectID == project.id {
                        appState.selectedProjectID = nil
                    }
                    modelContext.delete(project)
                    projectToDelete = nil
                }
            }
        } message: {
            Text("This will permanently delete \"\(projectToDelete?.name ?? "")\" and all its notes and tasks.")
        }
    }

    private func createProject() {
        let project = Project(name: "New Project")
        modelContext.insert(project)
        appState.selectedProjectID = project.id
    }

    private func moveSelection(_ direction: Int) {
        guard !projects.isEmpty else { return }
        if let current = appState.selectedProjectID,
           let idx = projects.firstIndex(where: { $0.id == current }) {
            let next = min(max(idx + direction, 0), projects.count - 1)
            appState.selectedProjectID = projects[next].id
        } else {
            appState.selectedProjectID = projects[direction > 0 ? 0 : projects.count - 1].id
        }
    }
}

private struct ProjectCard: View {
    let project: Project
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            Circle()
                .fill(Color(hex: project.color))
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: DS.Spacing.sm) {
                    Text(project.name)
                        .font(DS.Font.body)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    if project.isArchived {
                        DSPill(text: "Archived", color: .secondary)
                    }
                }
                if !project.summary.isEmpty {
                    Text(project.summary)
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Colors.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            HStack(spacing: DS.Spacing.sm) {
                if project.notes.count > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 8))
                        Text("\(project.notes.count)")
                            .font(DS.Font.small)
                    }
                    .foregroundStyle(DS.Colors.textTertiary)
                }
                if project.openTaskCount > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "checklist")
                            .font(.system(size: 8))
                        Text("\(project.openTaskCount)")
                            .font(DS.Font.small)
                    }
                    .foregroundStyle(DS.Colors.accent)
                }
            }
        }
        .padding(.vertical, DS.Spacing.sm)
    }
}
