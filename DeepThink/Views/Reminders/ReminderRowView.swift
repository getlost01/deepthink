import SwiftUI
import UserNotifications

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
                if reminder.isCompleted {
                    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [reminder.id.uuidString])
                    reminder.notificationScheduled = false
                } else {
                    scheduleReminderNotification(reminder, context: modelContext)
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
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: reminder.isOverdue ? "exclamationmark.circle.fill" : "bell.fill")
                            .font(.system(size: DS.IconSize.xs))
                        Text(date.formatted(date: .abbreviated, time: .shortened))
                            .font(DS.Font.small)
                        if reminder.repeatInterval != .none {
                            Image(systemName: "repeat")
                                .font(.system(size: DS.IconSize.xs))
                        }
                    }
                    .foregroundStyle(reminder.isOverdue ? DS.Colors.danger : DS.Colors.textTertiary)
                }
            }

            Spacer()

            HStack(spacing: DS.Spacing.xs) {
                if reminder.priority != .none {
                    Circle()
                        .fill(reminder.priority.color)
                        .frame(width: 7, height: 7)
                }
                if reminder.notificationScheduled, reminder.reminderDate != nil {
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: DS.IconSize.xs))
                        .foregroundStyle(DS.Colors.accent.opacity(0.6))
                }
            }
        }
        .padding(.vertical, DS.Spacing.xs)
    }
}
