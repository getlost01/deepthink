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
        HSplitView {
            // Left panel: task list
            VStack(spacing: 0) {
                VStack(spacing: DS.Spacing.sm) {
                    DSSearchField(text: $searchText, placeholder: "Search tasks...")

                    // Status filter pills
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: DS.Spacing.xs) {
                            statusPill(title: "All", status: nil)
                            statusPill(title: "In Progress", status: .inProgress)
                            statusPill(title: "To Do", status: .todo)
                            statusPill(title: "Backlog", status: .backlog)
                            statusPill(title: "Done", status: .done)
                        }
                    }

                    // Priority filter
                    Picker("Priority", selection: $priorityFilter) {
                        Text("All Priorities").tag(nil as TaskPriority?)
                        ForEach(TaskPriority.allCases) { priority in
                            Label(priority.rawValue, systemImage: priority.icon).tag(priority as TaskPriority?)
                        }
                    }
                    .pickerStyle(.menu)
                    .font(DS.Font.caption)
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
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) { deleteTask(task) } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
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
                                Button(role: .destructive) { deleteTask(task) } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                    .listStyle(.plain)
                }
            }
            .frame(minWidth: 240, idealWidth: 280, maxWidth: 360)
            .background(DS.Colors.surface)

            // Right panel: detail
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
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onReceive(NotificationCenter.default.publisher(for: .createNewTask)) { _ in
            let task = TaskItem(title: "")
            modelContext.insert(task)
            appState.selectedTaskID = task.id
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
    private func statusPill(title: String, status: TaskStatus?) -> some View {
        let isSelected = statusFilter == status

        Button {
            statusFilter = status
        } label: {
            Text(title)
                .font(DS.Font.tiny)
                .fontWeight(.medium)
                .foregroundStyle(isSelected ? .white : DS.Colors.textSecondary)
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.vertical, DS.Spacing.xs)
                .background(
                    isSelected ? (status?.color ?? DS.Colors.accent) : DS.Colors.inputBg,
                    in: Capsule()
                )
        }
        .buttonStyle(.plainPointer)
    }

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
                            .font(DS.Font.tiny)
                            .foregroundStyle(DS.Colors.textTertiary)
                    }
                }
            }

            Spacer()

            if let dueDate = task.dueDate {
                Text(dueDate.shortFormatted)
                    .font(DS.Font.tiny)
                    .foregroundStyle(task.isOverdue ? DS.Colors.error : DS.Colors.textTertiary)
            }
        }
        .padding(.vertical, DS.Spacing.xs)
    }
}
