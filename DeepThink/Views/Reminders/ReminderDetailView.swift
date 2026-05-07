import SwiftUI
import UserNotifications

struct ReminderDetailView: View {
    @Bindable var reminder: Reminder
    @State private var showCalendar = false
    @State private var showTimePicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: DS.Spacing.md) {
                Button {
                    withAnimation(DS.Animation.quick) {
                        reminder.isCompleted.toggle()
                        reminder.completedAt = reminder.isCompleted ? Date() : nil
                        reminder.modifiedAt = Date()
                        if reminder.isCompleted { cancelNotification(for: reminder) }
                    }
                } label: {
                    Image(systemName: reminder.isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(reminder.isCompleted ? DS.Colors.success : DS.Colors.textSecondary)
                        .font(.system(size: 24))
                }
                .buttonStyle(.plainPointer)

                TextField("What to remember?", text: $reminder.title)
                    .font(DS.Font.title)
                    .textFieldStyle(.plain)
                    .onChange(of: reminder.title) {
                        reminder.modifiedAt = Date()
                    }
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.top, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.md)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Spacing.sm) {
                    Button { showCalendar.toggle() } label: {
                        HStack(spacing: DS.Spacing.xs) {
                            Image(systemName: "calendar")
                                .font(.system(size: DS.IconSize.sm))
                                .foregroundStyle(dateChipColor)
                            Text(reminder.reminderDate?.shortFormatted ?? "Add date")
                                .foregroundStyle(reminder.reminderDate == nil ? DS.Colors.textTertiary : dateChipColor)
                        }
                        .font(DS.Font.caption)
                        .padding(.horizontal, DS.Spacing.sm + 2)
                        .padding(.vertical, DS.Spacing.xs + 2)
                        .background(DS.Colors.fillSecondary, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                    }
                    .buttonStyle(.plainPointer)
                    .popover(isPresented: $showCalendar) {
                        DSCalendarPicker(
                            selectedDate: Binding(
                                get: { reminder.reminderDate },
                                set: { newDate in
                                    if let newDate {
                                        let existing = reminder.reminderDate
                                        let cal = Calendar.current
                                        let hour = existing.map { cal.component(.hour, from: $0) } ?? cal.component(
                                            .hour,
                                            from: cal.date(byAdding: .hour, value: 1, to: Date())!
                                        )
                                        let minute = existing.map { cal.component(.minute, from: $0) } ?? 0
                                        var comps = cal.dateComponents([.year, .month, .day], from: newDate)
                                        comps.hour = hour
                                        comps.minute = minute
                                        reminder.reminderDate = cal.date(from: comps) ?? newDate
                                    } else {
                                        reminder.reminderDate = nil
                                        cancelNotification(for: reminder)
                                    }
                                    reminder.modifiedAt = Date()
                                }
                            ),
                            isPresented: $showCalendar
                        )
                    }

                    if reminder.reminderDate != nil {
                        Button { showTimePicker.toggle() } label: {
                            HStack(spacing: DS.Spacing.xs) {
                                Image(systemName: "clock")
                                    .font(.system(size: DS.IconSize.sm))
                                    .foregroundStyle(dateChipColor)
                                Text(reminder.reminderDate!.formatted(date: .omitted, time: .shortened))
                                    .foregroundStyle(dateChipColor)
                            }
                            .font(DS.Font.caption)
                            .padding(.horizontal, DS.Spacing.sm + 2)
                            .padding(.vertical, DS.Spacing.xs + 2)
                            .background(DS.Colors.fillSecondary, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                        }
                        .buttonStyle(.plainPointer)
                        .popover(isPresented: $showTimePicker) {
                            ReminderTimePicker(
                                date: Binding(
                                    get: { reminder.reminderDate! },
                                    set: { newDate in
                                        reminder.reminderDate = newDate
                                        reminder.modifiedAt = Date()
                                    }
                                ),
                                isPresented: $showTimePicker
                            )
                        }
                    }

                    if reminder.isOverdue {
                        HStack(spacing: DS.Spacing.xs) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: DS.IconSize.sm))
                            Text("Overdue")
                                .font(DS.Font.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundStyle(DS.Colors.danger)
                        .padding(.horizontal, DS.Spacing.sm + 2)
                        .padding(.vertical, DS.Spacing.xs + 2)
                        .background(DS.Colors.danger.opacity(0.1), in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                    }
                }
                .padding(.horizontal, DS.Spacing.xl)
            }
            .padding(.bottom, DS.Spacing.xs)

            Divider()
                .padding(.top, DS.Spacing.xs)

            RichMarkdownEditor(text: $reminder.notes)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            HStack(spacing: DS.Spacing.md) {
                Text("Created \(reminder.createdAt.shortFormatted)")
                if let completedAt = reminder.completedAt {
                    Text("• Completed \(completedAt.shortFormatted)")
                }
            }
            .font(DS.Font.small)
            .foregroundStyle(DS.Colors.textTertiary)
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.vertical, DS.Spacing.sm)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onChange(of: reminder.notes) { reminder.modifiedAt = Date() }
        .onChange(of: showCalendar) {
            if !showCalendar { scheduleNotification(for: reminder) }
        }
        .onChange(of: showTimePicker) {
            if !showTimePicker { scheduleNotification(for: reminder) }
        }
    }

    private var dateChipColor: Color {
        reminder.isOverdue ? DS.Colors.danger : DS.Colors.textPrimary
    }

    private func scheduleNotification(for reminder: Reminder) {
        guard let date = reminder.reminderDate, date > Date() else {
            print("[Notification] Skipped: date=\(String(describing: reminder.reminderDate)), now=\(Date())")
            return
        }

        let reminderID = reminder.id
        let reminderTitle = reminder.title

        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            print("[Notification] Authorization granted: \(granted), error: \(String(describing: error))")
            guard granted else { return }

            center.removePendingNotificationRequests(withIdentifiers: [reminderID.uuidString])

            let content = UNMutableNotificationContent()
            content.title = "DeepThink Reminder"
            content.body = reminderTitle.isEmpty ? "You have a reminder" : reminderTitle
            content.sound = .default
            content.interruptionLevel = .timeSensitive
            content.categoryIdentifier = "REMINDER"

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second], from: date
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

            let request = UNNotificationRequest(
                identifier: reminderID.uuidString,
                content: content,
                trigger: trigger
            )

            center.add(request) { error in
                if let error {
                    print("[Notification] Failed to schedule: \(error)")
                } else {
                    print("[Notification] Scheduled for \(date) id=\(reminderID)")
                }
            }
            DispatchQueue.main.async {
                reminder.notificationScheduled = true
            }
        }
    }

    private func cancelNotification(for reminder: Reminder) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [reminder.id.uuidString]
        )
        reminder.notificationScheduled = false
    }
}

// MARK: - Time Picker Popover

private struct ReminderTimePicker: View {
    @Binding var date: Date
    @Binding var isPresented: Bool
    @State private var editingDate: Date = .init()

    private let quickTimes: [(String, Int, Int)] = [
        ("9 AM", 9, 0),
        ("12 PM", 12, 0),
        ("3 PM", 15, 0),
        ("6 PM", 18, 0),
        ("9 PM", 21, 0)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Quick select")
                .font(DS.Font.small)
                .foregroundStyle(DS.Colors.textTertiary)

            HStack(spacing: DS.Spacing.xs) {
                ForEach(quickTimes, id: \.0) { label, hour, minute in
                    Button {
                        setTime(hour: hour, minute: minute)
                    } label: {
                        let isSelected = isTimeSelected(hour: hour, minute: minute)
                        Text(label)
                            .font(DS.Font.small)
                            .foregroundStyle(isSelected ? DS.Colors.onAccent : DS.Colors.textSecondary)
                            .padding(.horizontal, DS.Spacing.sm)
                            .padding(.vertical, DS.Spacing.xs)
                            .background(
                                isSelected ? DS.Colors.accent : DS.Colors.fillSecondary,
                                in: RoundedRectangle(cornerRadius: DS.Radius.sm)
                            )
                    }
                    .buttonStyle(.plainPointer)
                }
            }

            Divider()

            HStack(spacing: DS.Spacing.md) {
                Text("Select time")
                    .font(DS.Font.small)
                    .foregroundStyle(DS.Colors.textTertiary)

                DatePicker(
                    "Time",
                    selection: $editingDate,
                    displayedComponents: .hourAndMinute
                )
                .labelsHidden()
                .datePickerStyle(.stepperField)
            }

            Divider()

            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(.plainPointer)
                .foregroundStyle(DS.Colors.textSecondary)
                .font(DS.Font.caption)

                Spacer()

                Button("Done") {
                    date = editingDate
                    isPresented = false
                }
                .buttonStyle(.plainPointer)
                .foregroundStyle(DS.Colors.accent)
                .font(DS.Font.caption)
                .fontWeight(.semibold)
            }
        }
        .padding(DS.Spacing.lg)
        .frame(width: 260)
        .onAppear { editingDate = date }
    }

    private func setTime(hour: Int, minute: Int) {
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day], from: date)
        comps.hour = hour
        comps.minute = minute
        if let newDate = cal.date(from: comps) {
            date = newDate
        }
        isPresented = false
    }

    private func isTimeSelected(hour: Int, minute: Int) -> Bool {
        let cal = Calendar.current
        return cal.component(.hour, from: date) == hour &&
            cal.component(.minute, from: date) == minute
    }
}
