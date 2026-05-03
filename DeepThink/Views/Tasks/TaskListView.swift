import SwiftUI
import SwiftData

struct TaskListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Query(sort: \TaskItem.createdAt, order: .reverse) private var allTasks: [TaskItem]
    @State private var searchText = ""
    @State private var debouncedSearch = ""
    @State private var searchTask: Task<Void, Never>?
    @State private var filterStatus: TaskStatus?
    @Query(filter: #Predicate<Project> { !$0.isArchived }) private var allProjects: [Project]

    private var filteredTasks: [TaskItem] {
        var tasks = allTasks
        if let projectID = appState.filterProjectID {
            tasks = tasks.filter { $0.project?.id == projectID }
        }
        if let filterStatus { tasks = tasks.filter { $0.status == filterStatus } }
        if !debouncedSearch.isEmpty {
            let lowered = debouncedSearch.lowercased()
            tasks = tasks.filter { $0.title.lowercased().contains(lowered) || $0.detail.lowercased().contains(lowered) }
        }
        return tasks
    }

    private var filterProjectName: String? {
        guard let id = appState.filterProjectID else { return nil }
        return allProjects.first { $0.id == id }?.name
    }

    private var groupedTasks: [(TaskStatus, [TaskItem])] {
        let grouped = Dictionary(grouping: filteredTasks, by: \.status)
        return TaskStatus.allCases
            .sorted(by: { $0.sortOrder < $1.sortOrder })
            .compactMap { status in
                guard let tasks = grouped[status], !tasks.isEmpty else { return nil }
                return (status, tasks.sorted { ($0.priority.sortOrder, $0.createdAt) < ($1.priority.sortOrder, $1.createdAt) })
            }
    }

    var body: some View {
        @Bindable var appState = appState

        VStack(spacing: 0) {
            DSPageHeader(title: "Tasks") {
                Menu {
                    Button("All") { filterStatus = nil }
                    Divider()
                    ForEach(TaskStatus.allCases) { status in
                        Button {
                            filterStatus = status
                        } label: {
                            Label(status.rawValue, systemImage: status.icon)
                        }
                    }
                } label: {
                    Image(systemName: filterStatus == nil ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                        .font(.system(size: DS.IconSize.md, weight: .medium))
                        .foregroundStyle(filterStatus == nil ? DS.Colors.textSecondary : DS.Colors.accent)
                }
                .menuStyle(.borderlessButton)
                .frame(width: 28)

                DSToolbarButton(icon: "plus.circle.fill", color: DS.Colors.accent, size: DS.IconSize.lg) {
                    createTask()
                }
                .help("New Task (⌘T)")
            }

            DSSearchField(text: $searchText, placeholder: "Search tasks...")
                .padding(.horizontal, DS.Spacing.md)
                .padding(.bottom, DS.Spacing.sm)

            if let projectName = filterProjectName {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: DS.IconSize.sm))
                        .foregroundStyle(DS.Colors.accent)
                    Text(projectName)
                        .font(DS.Font.caption)
                        .fontWeight(.medium)
                    Button {
                        appState.filterByProject(nil)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: DS.IconSize.sm))
                            .foregroundStyle(DS.Colors.textTertiary)
                    }
                    .buttonStyle(.plainPointer)
                    Spacer()
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.bottom, DS.Spacing.sm)
            }

            if !filteredTasks.isEmpty {
                let done = filteredTasks.filter { $0.status == .done }.count
                let total = filteredTasks.count
                let progress = Double(done) / Double(total)
                HStack(spacing: DS.Spacing.sm) {
                    ProgressView(value: progress)
                        .tint(DS.Colors.accent)
                    Text("\(done)/\(total)")
                        .font(DS.Font.small)
                        .foregroundStyle(DS.Colors.textTertiary)
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.xs)
            }

            Divider()

            List(selection: $appState.selectedTaskID) {
                ForEach(groupedTasks, id: \.0) { status, tasks in
                    Section {
                        ForEach(tasks) { task in
                            TaskRowView(task: task)
                                .tag(task.id)
                                .contextMenu {
                                    ForEach(TaskStatus.allCases) { newStatus in
                                        Button("Mark as \(newStatus.rawValue)") {
                                            task.status = newStatus
                                            task.modifiedAt = Date()
                                        }
                                    }
                                    Divider()
                                    Button("Delete", role: .destructive) { deleteTask(task) }
                                }
                        }
                    } header: {
                        HStack(spacing: DS.Spacing.sm) {
                            Image(systemName: status.icon)
                                .font(.system(size: DS.IconSize.sm, weight: .medium))
                                .foregroundStyle(status.color)
                            Text(status.rawValue)
                                .font(DS.Font.caption)
                                .fontWeight(.medium)
                            DSPill(text: "\(tasks.count)", color: status.color)
                        }
                    }
                }
            }
            .listStyle(.inset)
            .overlay {
                if groupedTasks.isEmpty {
                    DSEmptyState(
                        icon: "checklist",
                        title: "No Tasks Yet",
                        subtitle: "Keep track of what you need to do. Set priorities and due dates so nothing falls through the cracks.",
                        hint: "Tasks can belong to a project, or stand on their own",
                        action: createTask,
                        actionTitle: "New Task"
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
        .onReceive(NotificationCenter.default.publisher(for: .createNewTask)) { _ in
            createTask()
        }
    }

    private func createTask() {
        let task = TaskItem(title: "New Task")
        modelContext.insert(task)
        appState.selectedTaskID = task.id
    }

    private func deleteTask(_ task: TaskItem) {
        if appState.selectedTaskID == task.id { appState.selectedTaskID = nil }
        modelContext.delete(task)
    }
}
