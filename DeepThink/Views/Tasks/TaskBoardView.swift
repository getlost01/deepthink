import SwiftData
import SwiftUI

struct TaskBoardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    let tasks: [TaskItem]

    private let columns: [TaskStatus] = [.backlog, .todo, .inProgress, .done]

    @State private var draggingTask: TaskItem?
    @State private var dropTargetStatus: TaskStatus?

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
        let isDropTarget = dropTargetStatus == status && draggingTask?.status != status
        let totalPoints = tasks.compactMap(\.storyPoints).reduce(0, +)

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

                if totalPoints > 0 {
                    Text("\(totalPoints)pt")
                        .font(DS.Font.small)
                        .foregroundStyle(DS.Colors.textTertiary)
                        .padding(.horizontal, DS.Spacing.xs)
                        .padding(.vertical, DS.Spacing.xxs)
                        .background(DS.Colors.fill, in: Capsule())
                }

                Spacer()

                if status == .done, !tasks.isEmpty {
                    Button {
                        withAnimation(DS.Animation.standard) {
                            for task in tasks {
                                task.isArchived = true
                                task.manuallyArchived = true
                                for subtask in task.subtasks {
                                    subtask.isArchived = true
                                }
                            }
                            try? modelContext.save()
                        }
                    } label: {
                        Text("Archive All")
                            .font(DS.Font.small)
                            .foregroundStyle(DS.Colors.textTertiary)
                            .padding(.horizontal, DS.Spacing.sm)
                            .padding(.vertical, DS.Spacing.xs)
                            .background(DS.Colors.fill, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                            .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm).strokeBorder(DS.Colors.border, lineWidth: 1))
                    }
                    .buttonStyle(.plainPointer)
                }

                Button {
                    let task = TaskItem(title: "")
                    task.status = status
                    modelContext.insert(task)
                    appState.selectedTaskID = task.id
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: DS.IconSize.xs, weight: .semibold))
                        .foregroundStyle(DS.Colors.textTertiary)
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plainPointer)
            }
            .padding(.bottom, DS.Spacing.xs)

            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: DS.Spacing.md) {
                    if tasks.isEmpty {
                        emptyColumnPlaceholder(isDropTarget: isDropTarget)
                    } else {
                        ForEach(tasks) { task in
                            boardCard(task: task)
                        }
                    }
                }
                .animation(DS.Animation.standard, value: tasks.map(\.id))
            }
            .frame(maxHeight: .infinity)
            .overlay {
                if isDropTarget, !tasks.isEmpty {
                    RoundedRectangle(cornerRadius: DS.Radius.md)
                        .strokeBorder(status.color.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                        .allowsHitTesting(false)
                }
            }
        }
        .frame(width: 280)
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(DS.Spacing.sm)
        .background(
            isDropTarget ? status.color.opacity(0.06) : DS.Colors.transparent,
            in: RoundedRectangle(cornerRadius: DS.Radius.md)
        )
        .animation(DS.Animation.quick, value: isDropTarget)
        .dropDestination(for: String.self) { items, _ in
            guard let taskIDString = items.first,
                  let taskID = UUID(uuidString: taskIDString),
                  let task = findTask(by: taskID) else { return false }
            guard task.status != status else { return false }
            withAnimation(DS.Animation.standard) {
                task.status = status
                task.modifiedAt = Date()
            }
            try? modelContext.save()
            dropTargetStatus = nil
            return true
        } isTargeted: { targeted in
            withAnimation(DS.Animation.quick) {
                dropTargetStatus = targeted ? status : (dropTargetStatus == status ? nil : dropTargetStatus)
            }
        }
    }

    private func findTask(by id: UUID) -> TaskItem? {
        tasks.first { $0.id == id }
    }

    private func emptyColumnPlaceholder(isDropTarget: Bool) -> some View {
        RoundedRectangle(cornerRadius: DS.Radius.md)
            .strokeBorder(
                isDropTarget ? DS.Colors.accent.opacity(DS.Opacity.disabled) : DS.Colors.border,
                style: StrokeStyle(lineWidth: 1, dash: isDropTarget ? [] : [6, 4])
            )
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .fill(isDropTarget ? DS.Colors.accentFill : DS.Colors.transparent)
            )
            .frame(height: 60)
            .overlay(
                Text(isDropTarget ? "Drop here" : "No tasks")
                    .font(DS.Font.small)
                    .foregroundStyle(isDropTarget ? DS.Colors.accent : DS.Colors.textTertiary)
            )
    }

    @ViewBuilder
    private func boardCard(task: TaskItem) -> some View {
        let isSelected = appState.selectedTaskID == task.id
        let isDragging = draggingTask?.id == task.id

        Button {
            appState.selectedTaskID = task.id
        } label: {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                HStack(alignment: .top, spacing: DS.Spacing.xs) {
                    Text(task.title.isEmpty ? "Untitled" : task.title)
                        .font(DS.Font.body)
                        .fontWeight(.medium)
                        .foregroundStyle(DS.Colors.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button {
                        if appState.selectedTaskID == task.id {
                            appState.selectedTaskID = nil
                        }
                        withAnimation(DS.Animation.standard) {
                            modelContext.delete(task)
                        }
                        try? modelContext.save()
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: DS.IconSize.xs, weight: .medium))
                            .foregroundStyle(DS.Colors.textTertiary)
                            .frame(width: 16, height: 16)
                            .background(DS.Colors.fill, in: Circle())
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plainPointer)
                }

                HStack(spacing: DS.Spacing.sm) {
                    if task.priority != .none {
                        HStack(spacing: 3) {
                            Image(systemName: task.priority.icon)
                                .font(.system(size: DS.IconSize.xs, weight: .medium))
                            Text(task.priority.rawValue)
                                .font(DS.Font.small)
                        }
                        .foregroundStyle(task.priority.color)
                    }

                    if let due = task.dueDate {
                        HStack(spacing: 3) {
                            Image(systemName: "calendar")
                                .font(.system(size: DS.IconSize.xs))
                            Text(due.shortFormatted)
                                .font(DS.Font.small)
                        }
                        .foregroundStyle(task.isOverdue ? DS.Colors.danger : DS.Colors.textTertiary)
                    }

                    if !task.subtasks.isEmpty {
                        let done = task.subtasks.count(where: { $0.status == .done })
                        HStack(spacing: 3) {
                            Image(systemName: "checklist")
                                .font(.system(size: DS.IconSize.xs))
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
                            .padding(.horizontal, DS.Spacing.xs)
                            .padding(.vertical, DS.Spacing.xxs)
                            .background(DS.Colors.fill, in: RoundedRectangle(cornerRadius: DS.Radius.xs))
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
            .background(DS.Colors.card, in: RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .strokeBorder(
                        isSelected ? DS.Colors.borderFocused : DS.Colors.border,
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
            .shadow(color: DS.Colors.cardShadow, radius: 2, y: 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plainPointer)
        .opacity(isDragging ? 0.5 : 1.0)
        .onDrag {
            draggingTask = task
            return NSItemProvider(object: task.id.uuidString as NSString)
        }
        .contextMenu {
            ForEach(TaskStatus.allCases) { newStatus in
                Button {
                    withAnimation(DS.Animation.standard) {
                        task.status = newStatus
                        task.modifiedAt = Date()
                    }
                    try? modelContext.save()
                } label: {
                    Label("Move to \(newStatus.rawValue)", systemImage: newStatus.icon)
                }
            }
            Divider()
            Button(role: .destructive) {
                modelContext.delete(task)
                try? modelContext.save()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
