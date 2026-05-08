import SwiftUI

struct ReminderRowView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var reminder: Reminder

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            Button {
                withAnimation(DS.Animation.quick) {
                    reminder.isCompleted.toggle()
                    reminder.completedAt = reminder.isCompleted ? Date() : nil
                    reminder.modifiedAt = Date()
                }
                try? modelContext.save()
            } label: {
                Image(systemName: reminder.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(reminder.isCompleted ? DS.Colors.success : DS.Colors.textSecondary)
                    .font(.system(size: DS.IconSize.lg))
            }
            .buttonStyle(.plainPointer)

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(reminder.title.isEmpty ? "Untitled" : reminder.title)
                    .font(DS.Font.body)
                    .lineLimit(1)
                    .strikethrough(reminder.isCompleted)
                    .foregroundStyle(reminder.isCompleted ? DS.Colors.textSecondary : DS.Colors.textPrimary)

                if let date = reminder.reminderDate {
                    HStack(spacing: 4) {
                        Image(systemName: reminder.isOverdue ? "exclamationmark.circle.fill" : "bell.fill")
                            .font(.system(size: DS.IconSize.xs))
                        Text(date.formatted(date: .abbreviated, time: .shortened))
                            .font(DS.Font.small)
                    }
                    .foregroundStyle(reminder.isOverdue ? DS.Colors.danger : DS.Colors.textTertiary)
                }
            }

            Spacer()
        }
        .padding(.vertical, DS.Spacing.xs)
    }
}
