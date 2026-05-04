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
    @State private var viewMode: TaskViewMode = .list
    @State private var smartFilter: SmartFilter = .all

    enum TaskViewMode: String {
        case list, board
    }

    enum SmartFilter: String, CaseIterable {
        case all = "All"
        case overdue = "Overdue"
    }

    private var filteredTasks: [TaskItem] {
        var result = tasks.filter { $0.parent == nil }

        switch smartFilter {
        case .all:
            break
        case .overdue:
            result = result.filter { $0.isOverdue }
        }

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
        if viewMode == .board {
            boardLayout
        } else {
            listLayout
        }
    }

    private var boardLayout: some View {
        VStack(spacing: 0) {
            VStack(spacing: DS.Spacing.sm) {
                HStack(spacing: DS.Spacing.sm) {
                    DSSearchField(text: $searchText, placeholder: "Search tasks...")
                    viewModeToggle
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DS.Spacing.sm) {
                        smartFilterChips

                        Picker(selection: $statusFilter) {
                            Text("All Statuses").tag(nil as TaskStatus?)
                            ForEach(TaskStatus.allCases) { s in
                                Label(s.rawValue, systemImage: s.icon).tag(s as TaskStatus?)
                            }
                        } label: { EmptyView() }
                        .pickerStyle(.menu)
                        .font(DS.Font.caption)
                        .fixedSize()

                        Picker(selection: $priorityFilter) {
                            Text("All Priorities").tag(nil as TaskPriority?)
                            ForEach(TaskPriority.allCases) { p in
                                Label(p.rawValue, systemImage: p.icon).tag(p as TaskPriority?)
                            }
                        } label: { EmptyView() }
                        .pickerStyle(.menu)
                        .font(DS.Font.caption)
                        .fixedSize()
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)

            Divider()

            TaskBoardView(tasks: filteredTasks)
        }
        .onReceive(NotificationCenter.default.publisher(for: .createNewTask)) { _ in
            let task = TaskItem(title: "")
            modelContext.insert(task)
            appState.selectedTaskID = task.id
            viewMode = .list
        }
    }

    private var smartFilterChips: some View {
        HStack(spacing: DS.Spacing.xs) {
            ForEach(SmartFilter.allCases, id: \.self) { filter in
                Button {
                    withAnimation(DS.Animation.quick) { smartFilter = filter }
                } label: {
                    Text(filter.rawValue)
                        .font(DS.Font.caption)
                        .fontWeight(smartFilter == filter ? .semibold : .regular)
                        .foregroundStyle(smartFilter == filter ? DS.Colors.accent : DS.Colors.textSecondary)
                        .padding(.horizontal, DS.Spacing.sm + 2)
                        .padding(.vertical, DS.Spacing.xs + 1)
                        .background(
                            smartFilter == filter ? DS.Colors.accentFill : DS.Colors.fill,
                            in: Capsule()
                        )
                }
                .buttonStyle(.plainPointer)
            }
        }
    }

    private var viewModeToggle: some View {
        HStack(spacing: 0) {
            Button {
                viewMode = .list
            } label: {
                Image(systemName: "list.bullet")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(viewMode == .list ? DS.Colors.accent : DS.Colors.textTertiary)
                    .frame(width: 28, height: 24)
            }
            .buttonStyle(.plainPointer)

            Button {
                viewMode = .board
            } label: {
                Image(systemName: "rectangle.split.3x1")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(viewMode == .board ? DS.Colors.accent : DS.Colors.textTertiary)
                    .frame(width: 28, height: 24)
            }
            .buttonStyle(.plainPointer)
        }
        .padding(.horizontal, 2)
        .background(DS.Colors.fill, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
    }

    private var listLayout: some View {
        ResizableSplitView(minLeftWidth: 240, minRightWidth: 400) {
            VStack(spacing: 0) {
                VStack(spacing: DS.Spacing.sm) {
                    HStack(spacing: DS.Spacing.sm) {
                        DSSearchField(text: $searchText, placeholder: "Search tasks...")
                        viewModeToggle
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: DS.Spacing.sm) {
                            smartFilterChips

                            Picker(selection: $statusFilter) {
                                Text("All Statuses").tag(nil as TaskStatus?)
                                ForEach(TaskStatus.allCases) { s in
                                    Label(s.rawValue, systemImage: s.icon).tag(s as TaskStatus?)
                                }
                            } label: { EmptyView() }
                            .pickerStyle(.menu)
                            .font(DS.Font.caption)
                            .fixedSize()

                            Picker(selection: $priorityFilter) {
                                Text("All Priorities").tag(nil as TaskPriority?)
                                ForEach(TaskPriority.allCases) { p in
                                    Label(p.rawValue, systemImage: p.icon).tag(p as TaskPriority?)
                                }
                            } label: { EmptyView() }
                            .pickerStyle(.menu)
                            .font(DS.Font.caption)
                            .fixedSize()
                        }
                    }
                }
                .padding(DS.Spacing.md)

                Divider()

                if filteredTasks.isEmpty {
                    DSEmptyState(
                        icon: "checklist",
                        title: "No Tasks Yet",
                        subtitle: searchText.isEmpty ? "Tasks help you track what needs to be done. Add priorities and due dates to stay organized." : "No tasks match your filters.",
                        hint: searchText.isEmpty ? "Start by adding something you need to get done this week" : nil
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredTasks) { task in
                                let isSelected = appState.selectedTaskID == task.id
                                Button { appState.selectedTaskID = task.id } label: {
                                    taskRow(task)
                                        .padding(.horizontal, DS.Spacing.sm)
                                        .padding(.vertical, 2)
                                        .background(isSelected ? DS.Colors.accentFill : .clear)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plainPointer)
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
                                Divider().padding(.horizontal, DS.Spacing.sm)
                            }
                        }
                    }
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
                    subtitle: "Pick a task from the list to see its details, set priority, or mark it done."
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

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
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

                    if !task.subtasks.isEmpty {
                        let done = task.subtasks.filter { $0.status == .done }.count
                        HStack(spacing: 2) {
                            Image(systemName: "checklist")
                                .font(.system(size: 8))
                            Text("\(done)/\(task.subtasks.count)")
                                .font(DS.Font.small)
                        }
                        .foregroundStyle(done == task.subtasks.count ? DS.Colors.success : DS.Colors.textTertiary)
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
        .padding(.vertical, DS.Spacing.sm)
    }
}
