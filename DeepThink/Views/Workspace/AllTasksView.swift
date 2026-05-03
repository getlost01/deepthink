import SwiftUI
import SwiftData

struct AllTasksView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskItem.modifiedAt, order: .reverse) private var tasks: [TaskItem]
    @Query private var projects: [Project]

    @State private var searchText: String = ""
    @State private var statusFilter: TaskStatus?
    @State private var priorityFilter: TaskPriority?
    @State private var taskToDelete: TaskItem?
    @State private var showDeleteConfirm = false

    private var filteredTasks: [TaskItem] {
        var result = tasks

        if let statusFilter {
            result = result.filter { $0.status == statusFilter }
        }

        if let priorityFilter {
            result = result.filter { $0.priority == priorityFilter }
        }

        if !searchText.isEmpty {
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.detail.localizedCaseInsensitiveContains(searchText)
            }
        }

        return result
    }

    private var selectedTask: TaskItem? {
        guard let id = appState.selectedTaskID else { return nil }
        return tasks.first { $0.id == id }
    }

    var body: some View {
        ResizableSplitView(minLeftWidth: 240, minRightWidth: 400) {
            VStack(spacing: 0) {
                VStack(spacing: DS.Spacing.sm) {
                    DSSearchField(text: $searchText, placeholder: "Search tasks...")

                    HStack(spacing: DS.Spacing.sm) {
                        Picker("Status", selection: $statusFilter) {
                            Text("All Statuses").tag(nil as TaskStatus?)
                            ForEach(TaskStatus.allCases) { s in
                                Label(s.rawValue, systemImage: s.icon).tag(s as TaskStatus?)
                            }
                        }
                        .pickerStyle(.menu)
                        .font(DS.Font.caption)

                        Picker("Priority", selection: $priorityFilter) {
                            Text("All Priorities").tag(nil as TaskPriority?)
                            ForEach(TaskPriority.allCases) { p in
                                Label(p.rawValue, systemImage: p.icon).tag(p as TaskPriority?)
                            }
                        }
                        .pickerStyle(.menu)
                        .font(DS.Font.caption)
                    }
                }
                .padding(DS.Spacing.md)

                Divider()

                if filteredTasks.isEmpty {
                    DSEmptyState(
                        icon: "checklist",
                        title: "No Tasks",
                        subtitle: searchText.isEmpty ? "Create your first task to get started." : "No tasks match your filters."
                    )
                } else {
                    List(filteredTasks, selection: Binding(
                        get: { appState.selectedTaskID },
                        set: { appState.selectedTaskID = $0 }
                    )) { task in
                        taskRow(task)
                            .tag(task.id)
                            .contextMenu {
                                Button { appState.selectedTaskID = task.id } label: {
                                    Label("Open", systemImage: "doc.text")
                                }
                                Button {
                                    task.status = .done
                                    task.completedAt = Date()
                                    task.modifiedAt = Date()
                                } label: {
                                    Label("Mark Done", systemImage: "checkmark.circle")
                                }
                                Divider()
                                Button(role: .destructive) { taskToDelete = task; showDeleteConfirm = true } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                    .listStyle(.plain)
                }
            }
            .background(DS.Colors.surface)
        } right: {
            if let task = selectedTask {
                TaskDetailView(task: task)
                    .id(task.id)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                DSEmptyState(
                    icon: "checklist",
                    title: "Select a Task",
                    subtitle: "Choose a task from the list to view details."
                )
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .createNewTask)) { _ in
            let task = TaskItem(title: "")
            modelContext.insert(task)
            appState.selectedTaskID = task.id
        }
        .confirmationDialog("Delete Task?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                if let task = taskToDelete {
                    deleteTask(task)
                    taskToDelete = nil
                }
            }
        } message: {
            Text("This will permanently delete \"\(taskToDelete?.title.isEmpty == false ? taskToDelete!.title : "Untitled")\".")
        }
    }

    private func deleteTask(_ task: TaskItem) {
        if appState.selectedTaskID == task.id {
            appState.selectedTaskID = nil
        }
        modelContext.delete(task)
    }

    // MARK: - Components

    @ViewBuilder
    private func taskRow(_ task: TaskItem) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: task.status.icon)
                .font(.system(size: DS.IconSize.sm))
                .foregroundStyle(task.status.color)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title.isEmpty ? "Untitled" : task.title)
                    .font(DS.Font.body)
                    .fontWeight(.medium)
                    .foregroundStyle(DS.Colors.textPrimary)
                    .lineLimit(1)

                HStack(spacing: DS.Spacing.xs) {
                    if task.priority != .none {
                        DSPill(text: task.priority.rawValue, color: task.priority.color)
                    }

                    if let project = task.project {
                        Text(project.name)
                            .font(DS.Font.small)
                            .foregroundStyle(DS.Colors.textTertiary)
                    }
                }
            }

            Spacer()

            if let dueDate = task.dueDate {
                Text(dueDate.shortFormatted)
                    .font(DS.Font.small)
                    .foregroundStyle(task.isOverdue ? DS.Colors.danger : DS.Colors.textTertiary)
            }
        }
        .padding(.vertical, DS.Spacing.xs)
    }
}
