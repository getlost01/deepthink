import SwiftData
import SwiftUI

struct WorkspaceOverviewView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Note> { !$0.isArchived }) private var notes: [Note]
    @Query(filter: #Predicate<TaskItem> { !$0.isArchived }) private var tasks: [TaskItem]
    @Query(filter: #Predicate<Project> { !$0.isArchived }) private var projects: [Project]
    @Query(filter: #Predicate<Reminder> { !$0.isCompleted }) private var activeReminders: [Reminder]

    private var todayReminders: [Reminder] {
        let cal = Calendar.current
        return activeReminders.filter { r in
            guard let date = r.reminderDate else { return false }
            return cal.isDateInToday(date)
        }.sorted { ($0.reminderDate ?? .distantFuture) < ($1.reminderDate ?? .distantFuture) }
    }

    private var recentNotes: [Note] {
        notes.sorted { $0.modifiedAt > $1.modifiedAt }.prefix(5).map(\.self)
    }

    private var overdueTasks: [TaskItem] {
        tasks.filter(\.isOverdue).sorted { ($0.dueDate ?? .distantPast) < ($1.dueDate ?? .distantPast) }
    }

    private var todayTasks: [TaskItem] {
        let cal = Calendar.current
        return tasks.filter { task in
            guard let due = task.dueDate, task.status != .done, task.status != .cancelled else { return false }
            return cal.isDateInToday(due)
        }
    }

    private var recentActiveTasks: [TaskItem] {
        tasks
            .filter { $0.status != .done && $0.status != .cancelled && $0.parent == nil }
            .sorted { $0.modifiedAt > $1.modifiedAt }
            .prefix(5)
            .map(\.self)
    }

    private var inProgressCount: Int {
        tasks.count(where: { $0.status == .inProgress })
    }

    private var completionRate: Double {
        let total = tasks.count
        guard total > 0 else { return 0 }
        return Double(tasks.count(where: { $0.status == .done })) / Double(total)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                // Stat cards
                HStack(spacing: DS.Spacing.md) {
                    DSStatCard(icon: "folder", label: "Projects", value: "\(projects.count)", color: DS.Colors.accent)
                    DSStatCard(icon: "doc.text", label: "Notes", value: "\(notes.count)", color: DS.Colors.knowledge)
                    DSStatCard(icon: "checklist", label: "Tasks", value: "\(tasks.count)", color: DS.Colors.success)
                    DSStatCard(icon: "circle.lefthalf.filled", label: "In Progress", value: "\(inProgressCount)", color: DS.Colors.warning)
                }

                // Completion progress
                if !tasks.isEmpty {
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        HStack {
                            Text("Overall Progress")
                                .font(DS.Font.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(DS.Colors.textSecondary)
                            Spacer()
                            Text("\(Int(completionRate * 100))%")
                                .font(DS.Font.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(DS.Colors.accent)
                        }
                        ProgressView(value: completionRate)
                            .tint(DS.Colors.accent)
                    }
                    .padding(.horizontal, DS.Spacing.sm)
                }

                // Overdue alert
                if !overdueTasks.isEmpty {
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        HStack(spacing: DS.Spacing.sm) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: DS.IconSize.sm))
                                .foregroundStyle(DS.Colors.danger)
                            Text("Overdue")
                                .font(DS.Font.heading)
                                .foregroundStyle(DS.Colors.danger)
                            DSPill(text: "\(overdueTasks.count)", color: DS.Colors.danger)
                            Spacer()
                        }

                        VStack(spacing: 0) {
                            ForEach(overdueTasks.prefix(3)) { task in
                                Button {
                                    appState.selectedTaskID = task.id
                                    appState.workspaceTab = .tasks
                                } label: {
                                    HStack(spacing: DS.Spacing.md) {
                                        Image(systemName: task.status.icon)
                                            .font(.system(size: DS.IconSize.sm))
                                            .foregroundStyle(DS.Colors.danger)
                                            .frame(width: 20)

                                        Text(task.title)
                                            .font(DS.Font.body)
                                            .foregroundStyle(DS.Colors.textPrimary)
                                            .lineLimit(1)

                                        Spacer()

                                        if let due = task.dueDate {
                                            Text(due.shortFormatted)
                                                .font(DS.Font.small)
                                                .foregroundStyle(DS.Colors.danger)
                                        }
                                    }
                                    .padding(.horizontal, DS.Spacing.md)
                                    .padding(.vertical, DS.Spacing.sm)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plainPointer)

                                if task.id != overdueTasks.prefix(3).last?.id {
                                    Divider().padding(.leading, DS.Layout.nestedListDividerInset + DS.Spacing.md)
                                }
                            }
                        }
                        .dsCard(padding: 0)
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.md)
                                .strokeBorder(DS.Colors.danger.opacity(0.2), lineWidth: 1)
                        )
                    }
                }

                // Today's tasks
                if !todayTasks.isEmpty {
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        DSSectionHeader(title: "Due Today", count: todayTasks.count)

                        VStack(spacing: 0) {
                            ForEach(todayTasks.prefix(5)) { task in
                                Button {
                                    appState.selectedTaskID = task.id
                                    appState.workspaceTab = .tasks
                                } label: {
                                    HStack(spacing: DS.Spacing.md) {
                                        Image(systemName: task.status.icon)
                                            .font(.system(size: DS.IconSize.sm))
                                            .foregroundStyle(task.status.color)
                                            .frame(width: 20)
                                        Text(task.title)
                                            .font(DS.Font.body)
                                            .foregroundStyle(DS.Colors.textPrimary)
                                            .lineLimit(1)
                                        Spacer()
                                        if task.priority != .none {
                                            DSPill(text: task.priority.rawValue, color: task.priority.color)
                                        }
                                    }
                                    .padding(.horizontal, DS.Spacing.md)
                                    .padding(.vertical, DS.Spacing.sm)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plainPointer)
                            }
                        }
                        .dsCard(padding: 0)
                    }
                }

                // Today's reminders
                if !todayReminders.isEmpty {
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        DSSectionHeader(title: "Today's Reminders", count: todayReminders.count) {
                            appState.navigate(to: .reminders)
                        }

                        VStack(spacing: 0) {
                            ForEach(todayReminders.prefix(4)) { reminder in
                                Button {
                                    appState.navigate(to: .reminders)
                                } label: {
                                    HStack(spacing: DS.Spacing.md) {
                                        Image(systemName: "bell.fill")
                                            .font(.system(size: DS.IconSize.sm))
                                            .foregroundStyle(reminder.isOverdue ? DS.Colors.danger : DS.Colors.accent)
                                            .frame(width: 20)
                                        Text(reminder.title.isEmpty ? "Untitled" : reminder.title)
                                            .font(DS.Font.body)
                                            .foregroundStyle(DS.Colors.textPrimary)
                                            .lineLimit(1)
                                        Spacer()
                                        if let date = reminder.reminderDate {
                                            Text(date, style: .time)
                                                .font(DS.Font.small)
                                                .foregroundStyle(reminder.isOverdue ? DS.Colors.danger : DS.Colors.textTertiary)
                                        }
                                        if reminder.priority != .none {
                                            Circle()
                                                .fill(reminder.priority.color)
                                                .frame(width: 6, height: 6)
                                        }
                                    }
                                    .padding(.horizontal, DS.Spacing.md)
                                    .padding(.vertical, DS.Spacing.sm)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plainPointer)
                                if reminder.id != todayReminders.prefix(4).last?.id {
                                    Divider().padding(.leading, DS.Layout.nestedListDividerInset + DS.Spacing.md)
                                }
                            }
                        }
                        .dsCard(padding: 0)
                    }
                }

                // Main content: notes + tasks
                HStack(alignment: .top, spacing: DS.Spacing.xl) {
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        DSSectionHeader(title: "Recent Notes", count: notes.count) {
                            appState.workspaceTab = .notes
                        }

                        if recentNotes.isEmpty {
                            emptyCard(icon: "doc.text", text: "No notes yet", hint: "Press ⌘N to create one")
                        } else {
                            VStack(spacing: 0) {
                                ForEach(recentNotes) { note in
                                    Button {
                                        appState.selectedNoteID = note.id
                                        appState.workspaceTab = .notes
                                    } label: {
                                        HStack(spacing: DS.Spacing.md) {
                                            Image(systemName: "doc.text")
                                                .font(.system(size: DS.IconSize.sm))
                                                .foregroundStyle(DS.Colors.textTertiary)
                                                .frame(width: 20)

                                            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                                                Text(note.title.isEmpty ? "Untitled" : note.title)
                                                    .font(DS.Font.body)
                                                    .foregroundStyle(DS.Colors.textPrimary)
                                                    .lineLimit(1)

                                                if let project = note.project {
                                                    Text(project.name)
                                                        .font(DS.Font.small)
                                                        .foregroundStyle(DS.Colors.textTertiary)
                                                }
                                            }

                                            Spacer()

                                            Text(note.modifiedAt.relativeFormatted)
                                                .font(DS.Font.small)
                                                .foregroundStyle(DS.Colors.textTertiary)
                                        }
                                        .padding(.horizontal, DS.Spacing.md)
                                        .padding(.vertical, DS.Spacing.sm)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plainPointer)

                                    if note.id != recentNotes.last?.id {
                                        Divider().padding(.leading, DS.Layout.nestedListDividerInset + DS.Spacing.md)
                                    }
                                }
                            }
                            .dsCard(padding: 0)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .top)

                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        DSSectionHeader(title: "Active Tasks", count: recentActiveTasks.count) {
                            appState.workspaceTab = .tasks
                        }

                        if recentActiveTasks.isEmpty {
                            emptyCard(icon: "checklist", text: "No active tasks", hint: "Press ⌘T to create one")
                        } else {
                            VStack(spacing: 0) {
                                ForEach(recentActiveTasks) { task in
                                    Button {
                                        appState.selectedTaskID = task.id
                                        appState.workspaceTab = .tasks
                                    } label: {
                                        HStack(spacing: DS.Spacing.md) {
                                            Image(systemName: task.status.icon)
                                                .font(.system(size: DS.IconSize.sm))
                                                .foregroundStyle(task.status.color)
                                                .frame(width: 20)

                                            Text(task.title.isEmpty ? "Untitled" : task.title)
                                                .font(DS.Font.body)
                                                .foregroundStyle(DS.Colors.textPrimary)
                                                .lineLimit(1)

                                            Spacer()

                                            if task.priority != .none {
                                                DSPill(text: task.priority.rawValue, color: task.priority.color)
                                            }
                                        }
                                        .padding(.horizontal, DS.Spacing.md)
                                        .padding(.vertical, DS.Spacing.sm)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plainPointer)

                                    if task.id != recentActiveTasks.last?.id {
                                        Divider().padding(.leading, DS.Layout.nestedListDividerInset + DS.Spacing.md)
                                    }
                                }
                            }
                            .dsCard(padding: 0)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .top)
                }

                // Project progress
                if !projects.isEmpty {
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        DSSectionHeader(title: "Projects", count: projects.count) {
                            appState.workspaceTab = .projects
                        }

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: DS.Spacing.md)], spacing: DS.Spacing.md) {
                            ForEach(projects.prefix(6)) { project in
                                Button {
                                    appState.selectedProjectID = project.id
                                    appState.workspaceTab = .projects
                                } label: {
                                    projectCard(project)
                                }
                                .buttonStyle(.plainPointer)
                            }
                        }
                    }
                }

                // Quick Actions
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    DSSectionHeader(title: "Quick Actions")

                    HStack(spacing: DS.Spacing.md) {
                        DSActionButton(title: "New Project", icon: "plus") {
                            appState.workspaceTab = .projects
                            NotificationCenter.default.post(name: .createNewProject, object: nil)
                        }

                        DSActionButton(title: "Ask AI", icon: "sparkles") {
                            appState.navigate(to: .aiAssistant)
                        }
                    }
                }
            }
            .padding(DS.Spacing.xl)
        }
        .dsPage()
    }

    @ViewBuilder
    private func projectCard(_ project: Project) -> some View {
        let total = project.tasks.count
        let done = project.completedTaskCount
        let progress = total > 0 ? Double(done) / Double(total) : 0

        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.sm) {
                Circle()
                    .fill(Color(hex: project.color))
                    .frame(width: 10, height: 10)
                Text(project.name)
                    .font(DS.Font.body)
                    .fontWeight(.medium)
                    .foregroundStyle(DS.Colors.textPrimary)
                    .lineLimit(1)
                Spacer()
            }

            if total > 0 {
                HStack(spacing: DS.Spacing.sm) {
                    ProgressView(value: progress)
                        .tint(Color(hex: project.color))
                    Text("\(done)/\(total)")
                        .font(DS.Font.small)
                        .foregroundStyle(DS.Colors.textTertiary)
                }
            }

            HStack(spacing: DS.Spacing.md) {
                HStack(spacing: 3) {
                    Image(systemName: "doc.text")
                        .font(.system(size: DS.IconSize.xs))
                    Text("\(project.notes.count)")
                        .font(DS.Font.small)
                }
                .foregroundStyle(DS.Colors.textTertiary)

                HStack(spacing: 3) {
                    Image(systemName: "checklist")
                        .font(.system(size: DS.IconSize.xs))
                    Text("\(project.openTaskCount) open")
                        .font(DS.Font.small)
                }
                .foregroundStyle(DS.Colors.textTertiary)

                if project.totalStoryPoints > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "number")
                            .font(.system(size: DS.IconSize.xs))
                        Text("\(project.completedStoryPoints)/\(project.totalStoryPoints) pts")
                            .font(DS.Font.small)
                    }
                    .foregroundStyle(DS.Colors.textTertiary)
                }
            }
        }
        .padding(DS.Spacing.md)
        .dsClickable()
    }

    private func emptyCard(icon: String, text: String, hint: String? = nil) -> some View {
        VStack(spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: DS.IconSize.md))
                    .foregroundStyle(DS.Colors.textTertiary)
                Text(text)
                    .font(DS.Font.body)
                    .foregroundStyle(DS.Colors.textTertiary)
            }
            if let hint {
                Text(hint)
                    .font(DS.Font.small)
                    .foregroundStyle(DS.Colors.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(DS.Spacing.xl)
        .background(DS.Colors.fill, in: RoundedRectangle(cornerRadius: DS.Radius.md))
    }
}
