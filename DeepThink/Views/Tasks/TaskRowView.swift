import SwiftUI

struct TaskRowView: View {
    @Bindable var task: TaskItem

    var body: some View {
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
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title.isEmpty ? "Untitled" : task.title)
                    .font(DS.Font.body)
                    .lineLimit(1)
                    .strikethrough(task.status == .done)
                    .foregroundStyle(task.status == .done ? DS.Colors.textSecondary : DS.Colors.textPrimary)

                if task.isOverdue, let due = task.dueDate {
                    Text("Overdue: \(due.shortFormatted)")
                        .font(DS.Font.tiny)
                        .foregroundStyle(DS.Colors.error)
                }
            }

            Spacer()

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
    }
}
