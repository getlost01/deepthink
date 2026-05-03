import SwiftUI
import SwiftData

struct TaskBoardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    let tasks: [TaskItem]

    private let columns: [TaskStatus] = [.backlog, .todo, .inProgress, .done]

    private func tasksFor(_ status: TaskStatus) -> [TaskItem] {
        tasks.filter { $0.status == status }
            .sorted { $0.priority.sortOrder < $1.priority.sortOrder }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            HStack(alignment: .top, spacing: DS.Spacing.md) {
                ForEach(columns, id: \.self) { status in
                    boardColumn(status: status, tasks: tasksFor(status))
                }
            }
            .padding(DS.Spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func boardColumn(status: TaskStatus, tasks: [TaskItem]) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.sm) {
                Circle()
                    .fill(status.color)
                    .frame(width: 8, height: 8)
                Text(status.rawValue)
                    .font(DS.Font.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(DS.Colors.textPrimary)
                Text("\(tasks.count)")
                    .font(DS.Font.small)
                    .foregroundStyle(DS.Colors.textTertiary)
                Spacer()

                Button {
                    let task = TaskItem(title: "")
                    task.status = status
                    modelContext.insert(task)
                    appState.selectedTaskID = task.id
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(DS.Colors.textTertiary)
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plainPointer)
            }
            .padding(.bottom, DS.Spacing.xs)

            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: DS.Spacing.md) {
                    if tasks.isEmpty {
                        RoundedRectangle(cornerRadius: DS.Radius.md)
                            .fill(DS.Colors.fill)
                            .frame(height: 48)
                            .overlay(
                                Text("No tasks")
                                    .font(DS.Font.small)
                                    .foregroundStyle(DS.Colors.textTertiary)
                            )
                    } else {
                        ForEach(tasks) { task in
                            boardCard(task: task)
                        }
                    }
                }
            }
        }
        .frame(width: 280)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private func boardCard(task: TaskItem) -> some View {
        Button {
            appState.selectedTaskID = task.id
        } label: {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                Text(task.title.isEmpty ? "Untitled" : task.title)
                    .font(DS.Font.body)
                    .fontWeight(.medium)
                    .foregroundStyle(DS.Colors.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                HStack(spacing: DS.Spacing.sm) {
                    if task.priority != .none {
                        HStack(spacing: 3) {
                            Image(systemName: task.priority.icon)
                                .font(.system(size: 9, weight: .medium))
                            Text(task.priority.rawValue)
                                .font(DS.Font.small)
                        }
                        .foregroundStyle(task.priority.color)
                    }

                    if let due = task.dueDate {
                        HStack(spacing: 3) {
                            Image(systemName: "calendar")
                                .font(.system(size: 9))
                            Text(due.shortFormatted)
                                .font(DS.Font.small)
                        }
                        .foregroundStyle(task.isOverdue ? DS.Colors.danger : DS.Colors.textTertiary)
                    }

                    if !task.subtasks.isEmpty {
                        let done = task.subtasks.filter { $0.status == .done }.count
                        HStack(spacing: 3) {
                            Image(systemName: "checklist")
                                .font(.system(size: 9))
                            Text("\(done)/\(task.subtasks.count)")
                                .font(DS.Font.small)
                        }
                        .foregroundStyle(done == task.subtasks.count ? DS.Colors.success : DS.Colors.textTertiary)
                    }

                    Spacer()

                    if let points = task.storyPoints {
                        Text("\(points)")
                            .font(DS.Font.small)
                            .fontWeight(.medium)
                            .foregroundStyle(DS.Colors.textTertiary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(DS.Colors.fill, in: RoundedRectangle(cornerRadius: 4))
                    }
                }

                if let project = task.project {
                    HStack(spacing: DS.Spacing.xs) {
                        Circle()
                            .fill(Color(hex: project.color))
                            .frame(width: 6, height: 6)
                        Text(project.name)
                            .font(DS.Font.small)
                            .foregroundStyle(DS.Colors.textTertiary)
                            .lineLimit(1)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DS.Spacing.lg)
            .background(DS.Colors.surface, in: RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .strokeBorder(
                        appState.selectedTaskID == task.id ? DS.Colors.accent.opacity(0.5) : DS.Colors.border,
                        lineWidth: 1
                    )
            )
            .shadow(color: DS.Colors.cardShadow, radius: 2, y: 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plainPointer)
        .contextMenu {
            ForEach(TaskStatus.allCases) { newStatus in
                Button("Move to \(newStatus.rawValue)") {
                    task.status = newStatus
                    task.modifiedAt = Date()
                }
            }
            Divider()
            Button("Delete", role: .destructive) {
                modelContext.delete(task)
            }
        }
    }
}
