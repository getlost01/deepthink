import SwiftUI

struct TaskRowView: View {
    @Bindable var task: TaskItem
    var depth: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: DS.Spacing.md) {
                Button {
                    withAnimation(DS.Animation.quick) {
                        task.status = task.status == .done ? .todo : .done
                        task.modifiedAt = Date()
                    }
                } label: {
                    Image(systemName: task.status == .done ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(task.status == .done ? DS.Colors.success : DS.Colors.textSecondary)
                        .font(.system(size: DS.IconSize.lg))
                }
                .buttonStyle(.plainPointer)

                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title.isEmpty ? "Untitled" : task.title)
                        .font(DS.Font.body)
                        .lineLimit(1)
                        .strikethrough(task.status == .done)
                        .foregroundStyle(task.status == .done ? DS.Colors.textSecondary : DS.Colors.textPrimary)

                    if task.isOverdue, let due = task.dueDate {
                        Text("Overdue: \(due.shortFormatted)")
                            .font(DS.Font.small)
                            .foregroundStyle(DS.Colors.danger)
                    }
                }

                Spacer()

                if !task.subtasks.isEmpty {
                    HStack(spacing: 2) {
                        Image(systemName: "list.bullet.indent")
                            .font(.system(size: 9))
                        let done = task.subtasks.filter { $0.status == .done }.count
                        Text("\(done)/\(task.subtasks.count)")
                            .font(DS.Font.small)
                    }
                    .foregroundStyle(DS.Colors.textTertiary)
                }

                if task.priority != .none {
                    Image(systemName: task.priority.icon)
                        .font(.system(size: DS.IconSize.sm, weight: .medium))
                        .foregroundStyle(task.priority.color)
                }

                if let points = task.storyPoints {
                    StoryPointsBadge(points: points)
                }
            }
            .padding(.vertical, DS.Spacing.xs)
            .padding(.leading, CGFloat(depth) * 24)
        }
    }
}
