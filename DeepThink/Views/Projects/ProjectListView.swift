import SwiftData
import SwiftUI

struct ProjectListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Query(sort: \Project.createdAt, order: .reverse) private var allProjects: [Project]
    @State private var searchText = ""
    @State private var debouncedSearch = ""
    @State private var searchTask: Task<Void, Never>?
    @State private var showArchived = false
    @State private var projectToDelete: Project?
    @State private var showDeleteConfirm = false

    private var projects: [Project] {
        var result = showArchived ? allProjects.filter(\.isArchived) : allProjects.filter { !$0.isArchived }
        if !debouncedSearch.isEmpty {
            let lowered = debouncedSearch.lowercased()
            result = result.filter { $0.name.lowercased().contains(lowered) || $0.summary.lowercased().contains(lowered) }
        }
        return result
    }

    var body: some View {
        @Bindable var appState = appState

        VStack(spacing: 0) {
            HStack(spacing: DS.Spacing.sm) {
                DSSearchField(text: $searchText, placeholder: "Search projects...")

                DSArchiveButton(isOn: showArchived, count: allProjects.count(where: { $0.isArchived })) { showArchived.toggle() }

                DSAddButton {
                    createProject()
                }
                .help("New Project (⇧⌘N)")
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.sm)

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(projects) { project in
                            let isSelected = appState.selectedProjectID == project.id
                            Button {
                                appState.selectedProjectID = project.id
                            } label: {
                                ProjectCard(project: project)
                                    .padding(.horizontal, DS.Spacing.sm)
                                    .padding(.vertical, DS.Spacing.xxs)
                                    .background(isSelected ? DS.Colors.accentFill : .clear)
                                    .contentShape(Rectangle())
                            }
                            .id(project.id)
                            .buttonStyle(.plainPointer)
                            .contextMenu {
                                Button {
                                    let archiving = !project.isArchived
                                    project.isArchived = archiving
                                    project.modifiedAt = Date()
                                    if archiving {
                                        ArchiveService.archiveProjectTasks(project, context: modelContext)
                                    } else {
                                        ArchiveService.unarchiveProjectTasks(project, context: modelContext)
                                    }
                                } label: {
                                    Label(project.isArchived ? "Unarchive" : "Archive", systemImage: project.isArchived ? "archivebox" : "archivebox.fill")
                                }
                                Divider()
                                Button(role: .destructive) {
                                    projectToDelete = project
                                    showDeleteConfirm = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            if project.id != projects.last?.id {
                                Divider()
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
                .onChange(of: appState.selectedProjectID) { _, id in
                    guard let id else { return }
                    proxy.scrollTo(id, anchor: .center)
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
        .onChange(of: appState.selectedProjectID) { _, id in
            appState.projectDetailMode = .overview
            guard let id, !showArchived else { return }
            if let project = allProjects.first(where: { $0.id == id }), project.isArchived {
                showArchived = true
            }
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
            Text("This will permanently delete \"\(projectToDelete?.name ?? "")\" and all its notes, tasks, and reminders.")
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

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
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
                        .font(DS.Font.small)
                        .foregroundStyle(DS.Colors.textTertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            HStack(spacing: DS.Spacing.sm) {
                let noteCount = project.isArchived ? project.notes.count : project.notes.count(where: { !$0.isArchived })
                let taskCount = project.isArchived ? project.tasks.count : project.openTaskCount
                if noteCount > 0 {
                    HStack(spacing: DS.Spacing.xxs) {
                        Image(systemName: "doc.text")
                            .font(.system(size: DS.IconSize.xs))
                        Text("\(noteCount)")
                            .font(DS.Font.small)
                    }
                    .foregroundStyle(DS.Colors.textTertiary)
                }
                if taskCount > 0 {
                    HStack(spacing: DS.Spacing.xxs) {
                        Image(systemName: "checklist")
                            .font(.system(size: DS.IconSize.xs))
                        Text("\(taskCount)")
                            .font(DS.Font.small)
                    }
                    .foregroundStyle(project.isArchived ? DS.Colors.textTertiary : DS.Colors.accent)
                }
            }
        }
        .padding(.vertical, DS.Spacing.sm)
    }
}
