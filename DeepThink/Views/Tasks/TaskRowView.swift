import SwiftUI

struct TaskRowView: View {
    @Bindable var task: TaskItem

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    task.status = task.status == .done ? .todo : .done
                    task.modifiedAt = Date()
                }
            } label: {
                Image(systemName: task.status == .done ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(task.status == .done ? .green : .secondary)
                    .font(.system(size: 14))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title.isEmpty ? "Untitled" : task.title)
                    .lineLimit(1)
                    .strikethrough(task.status == .done)
                    .foregroundStyle(task.status == .done ? .secondary : .primary)

                if task.isOverdue, let due = task.dueDate {
                    Text("Overdue: \(due.shortFormatted)")
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            }

            Spacer()

            if task.priority != .none {
                Image(systemName: task.priority.icon)
                    .font(.system(size: 10))
                    .foregroundStyle(task.priority.color)
            }

            if let points = task.storyPoints {
                StoryPointsBadge(points: points)
            }
        }
        .padding(.vertical, DS.Spacing.xs)
    }
}
