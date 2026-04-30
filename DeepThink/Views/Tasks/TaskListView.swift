import SwiftUI
import SwiftData

struct TaskListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Query(sort: \TaskItem.createdAt, order: .reverse) private var allTasks: [TaskItem]
    @State private var searchText = ""
    @State private var filterStatus: TaskStatus?

    private var filteredTasks: [TaskItem] {
        var tasks = allTasks
        if let filterStatus { tasks = tasks.filter { $0.status == filterStatus } }
        if !searchText.isEmpty {
            let lowered = searchText.lowercased()
            tasks = tasks.filter { $0.title.lowercased().contains(lowered) || $0.detail.lowercased().contains(lowered) }
        }
        return tasks
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
            HStack(spacing: DS.Spacing.sm) {
                Text("Tasks")
                    .font(DS.Font.heading)
                Spacer()

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
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(filterStatus == nil ? DS.Colors.textSecondary : DS.Colors.accent)
                }
                .menuStyle(.borderlessButton)
                .frame(width: 24)

                Button(action: createTask) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(DS.Colors.accent)
                }
                .buttonStyle(.plain)
                .help("New Task (⌘T)")
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)

            DSSearchField(text: $searchText, placeholder: "Search tasks...")
                .padding(.horizontal, DS.Spacing.md)
                .padding(.bottom, DS.Spacing.sm)

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
                                .font(.system(size: 10))
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
                        title: "No Tasks",
                        subtitle: "Create your first task",
                        action: createTask,
                        actionTitle: "New Task"
                    )
                }
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
