import SwiftData
import SwiftUI
import UserNotifications

struct ReminderDetailView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Bindable var reminder: Reminder
    @Query(filter: #Predicate<Note> { !$0.isArchived }) private var allNotes: [Note]
    @Query(filter: #Predicate<TaskItem> { !$0.isArchived }) private var allTasksForScan: [TaskItem]
    @Query private var allRemindersForScan: [Reminder]
    @State private var showDatePicker = false
    @State private var linkPickerType: String?
    @State private var linkInsertRequest: DeepLinkInsertRequest?
    @State private var hasDeadLinks = false
    @State private var deadLinkUUIDs: Set<String> = []
    @State private var cleanDeadLinksRequest: UUID?
    @State private var deadLinkTask: Task<Void, Never>?
    @State private var titleRescheduleTask: Task<Void, Never>?
    @State private var showPriorityPicker = false
    @State private var showRepeatPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: DS.Spacing.md) {
                Button {
                    withAnimation(DS.Animation.quick) {
                        reminder.isCompleted.toggle()
                        reminder.completedAt = reminder.isCompleted ? Date() : nil
                        reminder.modifiedAt = Date()
                    }
                    if reminder.isCompleted {
                        cancelNotification(for: reminder)
                    } else {
                        scheduleNotification(for: reminder)
                    }
                    try? modelContext.save()
                } label: {
                    Image(systemName: reminder.isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(reminder.isCompleted ? DS.Colors.success : DS.Colors.textSecondary)
                        .font(.system(size: DS.IconSize.xxl))
                }
                .buttonStyle(.plainPointer)

                TextField("What to remember?", text: $reminder.title)
                    .font(DS.Font.title)
                    .textFieldStyle(.plain)
                    .dsThemedTextInput()
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.top, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.md)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Spacing.sm) {
                    // Date + time chip → opens custom calendar popover
                    Button { showDatePicker.toggle() } label: {
                        HStack(spacing: DS.Spacing.xs) {
                            Image(systemName: "calendar")
                                .font(.system(size: DS.IconSize.sm))
                                .foregroundStyle(dateChipColor)
                            if let date = reminder.reminderDate {
                                Text(date, format: .dateTime.month(.abbreviated).day().hour().minute())
                                    .font(DS.Font.caption)
                                    .foregroundStyle(dateChipColor)
                                if reminder.notificationScheduled {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: DS.IconSize.xs))
                                        .foregroundStyle(DS.Colors.success)
                                }
                            } else {
                                Text("Set date & time")
                                    .font(DS.Font.caption)
                                    .foregroundStyle(DS.Colors.textTertiary)
                            }
                            if reminder.reminderDate != nil {
                                Button {
                                    reminder.reminderDate = nil
                                    reminder.repeatInterval = .none
                                    cancelNotification(for: reminder)
                                    reminder.modifiedAt = Date()
                                    try? modelContext.save()
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: DS.IconSize.nano, weight: .semibold))
                                        .foregroundStyle(DS.Colors.textTertiary)
                                }
                                .buttonStyle(.plainPointer)
                            }
                        }
                        .padding(.horizontal, DS.Spacing.sm2)
                        .padding(.vertical, DS.Spacing.xs2)
                        .background(
                            reminder.reminderDate != nil ? DS.Colors.fillSecondary : DS.Colors.fill,
                            in: RoundedRectangle(cornerRadius: DS.Radius.sm)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.sm)
                                .strokeBorder(
                                    reminder.isOverdue ? DS.Colors.badgeBorder(DS.Colors.danger) : DS.Colors.border,
                                    lineWidth: 1
                                )
                        )
                    }
                    .buttonStyle(.plainPointer)
                    .popover(isPresented: $showDatePicker, arrowEdge: .bottom) {
                        ReminderDatePickerPopover(
                            existingDate: reminder.reminderDate,
                            isPresented: $showDatePicker,
                            onClear: {
                                reminder.reminderDate = nil
                                reminder.repeatInterval = .none
                                cancelNotification(for: reminder)
                                reminder.modifiedAt = Date()
                                try? modelContext.save()
                            },
                            onConfirm: { newDate in
                                reminder.reminderDate = newDate
                                reminder.modifiedAt = Date()
                                try? modelContext.save()
                                scheduleNotification(for: reminder)
                            }
                        )
                    }

                    // Priority picker
                    Button { showPriorityPicker.toggle() } label: {
                        HStack(spacing: DS.Spacing.xs) {
                            if reminder.priority != .none {
                                Circle()
                                    .fill(reminder.priority.color)
                                    .frame(width: 7, height: 7)
                            }
                            Image(systemName: reminder.priority == .none ? "flag" : "flag.fill")
                                .font(.system(size: DS.IconSize.sm))
                                .foregroundStyle(reminder.priority == .none ? DS.Colors.textTertiary : reminder.priority.color)
                            if reminder.priority != .none {
                                Text(reminder.priority.label)
                                    .font(DS.Font.caption)
                                    .foregroundStyle(reminder.priority.color)
                            }
                        }
                        .padding(.horizontal, DS.Spacing.sm2)
                        .padding(.vertical, DS.Spacing.xs2)
                        .background(
                            reminder.priority != .none
                                ? DS.Colors.badgeFill(reminder.priority.color)
                                : DS.Colors.fillSecondary,
                            in: RoundedRectangle(cornerRadius: DS.Radius.sm)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.sm)
                                .strokeBorder(
                                    reminder.priority != .none
                                        ? DS.Colors.badgeBorder(reminder.priority.color)
                                        : DS.Colors.border,
                                    lineWidth: 1
                                )
                        )
                    }
                    .buttonStyle(.plainPointer)
                    .popover(isPresented: $showPriorityPicker, arrowEdge: .bottom) {
                        PriorityPickerPopover(
                            priority: Binding(get: { reminder.priority }, set: { reminder.priority = $0 }),
                            isPresented: $showPriorityPicker
                        ) {
                            reminder.modifiedAt = Date()
                            try? modelContext.save()
                        }
                    }

                    // Repeat picker
                    Button { showRepeatPicker.toggle() } label: {
                        HStack(spacing: DS.Spacing.xs) {
                            Image(systemName: "repeat")
                                .font(.system(size: DS.IconSize.sm))
                                .foregroundStyle(reminder.repeatInterval != .none ? DS.Colors.accent : DS.Colors.textTertiary)
                            Text(reminder.repeatInterval.shortLabel)
                                .font(DS.Font.caption)
                                .foregroundStyle(reminder.repeatInterval != .none ? DS.Colors.accent : DS.Colors.textTertiary)
                        }
                        .padding(.horizontal, DS.Spacing.sm2)
                        .padding(.vertical, DS.Spacing.xs2)
                        .background(
                            reminder.repeatInterval != .none ? DS.Colors.accentFill : DS.Colors.fillSecondary,
                            in: RoundedRectangle(cornerRadius: DS.Radius.sm)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.sm)
                                .strokeBorder(
                                    reminder.repeatInterval != .none ? DS.Colors.badgeBorder(DS.Colors.accent) : DS.Colors.border,
                                    lineWidth: 1
                                )
                        )
                    }
                    .buttonStyle(.plainPointer)
                    .popover(isPresented: $showRepeatPicker, arrowEdge: .bottom) {
                        RepeatPickerPopover(
                            repeatInterval: Binding(get: { reminder.repeatInterval }, set: { reminder.repeatInterval = $0 }),
                            isPresented: $showRepeatPicker
                        ) {
                            reminder.modifiedAt = Date()
                            try? modelContext.save()
                            scheduleNotification(for: reminder)
                        }
                    }

                    // Project chip
                    if let project = reminder.project {
                        HStack(spacing: DS.Spacing.xs) {
                            Circle()
                                .fill(Color(hex: project.color))
                                .frame(width: 7, height: 7)
                            Text(project.name)
                                .font(DS.Font.caption)
                                .foregroundStyle(DS.Colors.textSecondary)
                        }
                        .padding(.horizontal, DS.Spacing.sm2)
                        .padding(.vertical, DS.Spacing.xs2)
                        .background(DS.Colors.fillSecondary, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
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
                        .padding(.horizontal, DS.Spacing.sm2)
                        .padding(.vertical, DS.Spacing.xs2)
                        .background(DS.Colors.badgeFill(DS.Colors.danger), in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                    }
                }
                .padding(.horizontal, DS.Spacing.xl)
            }
            .padding(.bottom, DS.Spacing.xs)

            Divider()
                .padding(.top, DS.Spacing.xs)

            if hasDeadLinks {
                DSWarningStrip(
                    message: "Contains broken links to deleted items",
                    actionTitle: "Fix"
                ) {
                    cleanDeadLinksRequest = UUID()
                }
            }

            RichMarkdownEditor(
                text: $reminder.notes,
                onLinkClick: { url in appState.handleDeepLink(url) },
                onRequestLinkInsert: { type in linkPickerType = type },
                linkInsertRequest: linkInsertRequest,
                deadLinkUUIDs: deadLinkUUIDs,
                onRequestDeadLinkClean: { hasDeadLinks = false; deadLinkUUIDs = [] },
                cleanDeadLinksRequest: cleanDeadLinksRequest
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .sheet(isPresented: Binding(get: { linkPickerType != nil }, set: { if !$0 { linkPickerType = nil } })) {
                if let type = linkPickerType {
                    DeepLinkPickerSheet(type: type, onSelect: { title, url in
                        linkInsertRequest = DeepLinkInsertRequest(text: title, url: url)
                        linkPickerType = nil
                    }, onDismiss: { linkPickerType = nil })
                }
            }

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
        .onChange(of: reminder.title) {
            reminder.modifiedAt = Date()
            try? modelContext.save()
            guard reminder.notificationScheduled else { return }
            titleRescheduleTask?.cancel()
            titleRescheduleTask = Task {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                await MainActor.run { scheduleNotification(for: reminder) }
            }
        }
        .onChange(of: reminder.notes) { reminder.modifiedAt = Date(); try? modelContext.save(); scheduleScanDeadLinks() }
        .onAppear { scheduleScanDeadLinks() }
    }

    private func scheduleScanDeadLinks() {
        deadLinkTask?.cancel()
        let content = reminder.notes
        let tasks = allTasksForScan, notes = allNotes, reminders = allRemindersForScan
        deadLinkTask = Task {
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            let dead = DeadLinkScanner.deadLinkUUIDs(in: content, tasks: tasks, notes: notes, reminders: reminders)
            await MainActor.run {
                deadLinkUUIDs = dead
                hasDeadLinks = !dead.isEmpty
            }
        }
    }

    private var dateChipColor: Color {
        if reminder.isCompleted { return DS.Colors.textTertiary }
        return reminder.isOverdue ? DS.Colors.danger : DS.Colors.textPrimary
    }

    private func scheduleNotification(for reminder: Reminder) {
        guard let date = reminder.reminderDate, date > Date() else {
            if reminder.notificationScheduled {
                reminder.notificationScheduled = false
                try? modelContext.save()
            }
            return
        }

        let context = modelContext
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized,
                 .provisional:
                scheduleRequest(center: center, reminder: reminder, date: date, context: context)
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    guard granted else { return }
                    scheduleRequest(center: center, reminder: reminder, date: date, context: context)
                }
            default:
                break
            }
        }
    }

    private func scheduleRequest(center: UNUserNotificationCenter, reminder: Reminder, date: Date, context: ModelContext) {
        center.removePendingNotificationRequests(withIdentifiers: [reminder.id.uuidString])

        let content = UNMutableNotificationContent()
        content.title = "DeepThink Reminder"
        content.body = reminder.title.isEmpty ? "You have a reminder" : reminder.title
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        content.categoryIdentifier = "REMINDER"

        let cal = Calendar.current
        let components: DateComponents
        let repeats: Bool
        switch reminder.repeatInterval {
        case .none:
            components = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
            repeats = false
        case .daily:
            components = cal.dateComponents([.hour, .minute], from: date)
            repeats = true
        case .weekly:
            components = cal.dateComponents([.weekday, .hour, .minute], from: date)
            repeats = true
        case .monthly:
            components = cal.dateComponents([.day, .hour, .minute], from: date)
            repeats = true
        case .yearly:
            components = cal.dateComponents([.month, .day, .hour, .minute], from: date)
            repeats = true
        }

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: repeats)
        let request = UNNotificationRequest(identifier: reminder.id.uuidString, content: content, trigger: trigger)

        center.add(request) { error in
            guard error == nil else { return }
            DispatchQueue.main.async {
                reminder.notificationScheduled = true
                try? context.save()
            }
        }
    }

    private func cancelNotification(for reminder: Reminder) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [reminder.id.uuidString]
        )
        reminder.notificationScheduled = false
        try? modelContext.save()
    }
}

// MARK: - Priority Picker Popover

private struct PriorityPickerPopover: View {
    @Binding var priority: ReminderPriority
    @Binding var isPresented: Bool
    let onChange: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Priority")
                .font(DS.Font.caption)
                .fontWeight(.semibold)
                .foregroundStyle(DS.Colors.textTertiary)
                .padding(.horizontal, DS.Spacing.md)
                .padding(.top, DS.Spacing.md)
                .padding(.bottom, DS.Spacing.xs)

            ForEach(ReminderPriority.allCases, id: \.rawValue) { p in
                PickerOptionRow(
                    label: p.label,
                    icon: p.icon,
                    iconColor: p == .none ? DS.Colors.textTertiary : p.color,
                    isSelected: priority == p
                ) {
                    priority = p
                    onChange()
                    isPresented = false
                }
            }
        }
        .frame(width: 200)
        .padding(.bottom, DS.Spacing.sm)
        .background(DS.Colors.modal)
    }
}

// MARK: - Repeat Picker Popover

private struct RepeatPickerPopover: View {
    @Binding var repeatInterval: ReminderRepeat
    @Binding var isPresented: Bool
    let onChange: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Repeat")
                .font(DS.Font.caption)
                .fontWeight(.semibold)
                .foregroundStyle(DS.Colors.textTertiary)
                .padding(.horizontal, DS.Spacing.md)
                .padding(.top, DS.Spacing.md)
                .padding(.bottom, DS.Spacing.xs)

            ForEach(ReminderRepeat.allCases, id: \.rawValue) { r in
                PickerOptionRow(
                    label: r.label,
                    icon: r == .none ? "minus" : "repeat",
                    iconColor: r == .none ? DS.Colors.textTertiary : DS.Colors.accent,
                    isSelected: repeatInterval == r
                ) {
                    repeatInterval = r
                    onChange()
                    isPresented = false
                }
            }
        }
        .frame(width: 180)
        .padding(.bottom, DS.Spacing.sm)
        .background(DS.Colors.modal)
    }
}

// MARK: - Shared Picker Row

private struct PickerOptionRow: View {
    let label: String
    let icon: String
    let iconColor: Color
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: DS.IconSize.sm))
                    .foregroundStyle(iconColor)
                    .frame(width: DS.Spacing.lg)
                Text(label)
                    .font(DS.Font.body)
                    .foregroundStyle(DS.Colors.textPrimary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: DS.IconSize.xs, weight: .semibold))
                        .foregroundStyle(DS.Colors.accent)
                }
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .background(isSelected || isHovered ? DS.Colors.fillSecondary : DS.Colors.transparent)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plainPointer)
        .onHover { isHovered = $0 }
        .animation(DS.Animation.quick, value: isHovered)
    }
}

// MARK: - Calendar Picker Popover

private struct ReminderDatePickerPopover: View {
    let existingDate: Date?
    @Binding var isPresented: Bool
    let onClear: () -> Void
    let onConfirm: (Date) -> Void

    @State private var viewMonth: Date
    @State private var pickedDate: Date

    private let cal = Calendar.current
    // 7 × 32 + 6 × 4 = 248, + 2 × 16 padding = 280
    private let gridCols = Array(repeating: GridItem(.fixed(32), spacing: 4), count: 7)
    private let quickTimes: [(String, Int)] = [("Morn", 9), ("Noon", 12), ("Eve", 18), ("Night", 21)]

    init(existingDate: Date?, isPresented: Binding<Bool>, onClear: @escaping () -> Void, onConfirm: @escaping (Date) -> Void) {
        self.existingDate = existingDate
        _isPresented = isPresented
        self.onClear = onClear
        self.onConfirm = onConfirm
        let base = existingDate ?? Date()
        _viewMonth = State(initialValue: base)
        _pickedDate = State(initialValue: existingDate ?? Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date())
    }

    var body: some View {
        VStack(spacing: 0) {
            shortcutsRow
            Divider()
            calendarSection
            Divider()
            timeSection
            Divider()
            actionsRow
        }
        .frame(width: 280)
        .background(DS.Colors.modal)
    }

    // MARK: Shortcuts

    private var shortcutsRow: some View {
        HStack(spacing: DS.Spacing.xs) {
            ForEach(quickDates, id: \.0) { label, date in
                let isActive = cal.isDate(pickedDate, inSameDayAs: date)
                Button {
                    withAnimation(DS.Animation.quick) { pickedDate = date; viewMonth = date }
                } label: {
                    Text(label)
                        .font(DS.Font.small)
                        .fontWeight(isActive ? .semibold : .regular)
                        .foregroundStyle(isActive ? DS.Colors.onAccent : DS.Colors.accent)
                        .padding(.horizontal, DS.Spacing.sm)
                        .padding(.vertical, DS.Spacing.xs)
                        .background(isActive ? DS.Colors.accent : DS.Colors.accentFill, in: Capsule())
                        .overlay(Capsule().strokeBorder(DS.Colors.accent.opacity(isActive ? 0 : 0.2), lineWidth: 1))
                }
                .buttonStyle(.plainPointer)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.sm2)
    }

    // MARK: Calendar Grid

    private var calendarSection: some View {
        VStack(spacing: DS.Spacing.xs) {
            monthHeader
                .padding(.top, DS.Spacing.sm)

            // Weekday labels
            LazyVGrid(columns: gridCols, spacing: 4) {
                ForEach(Array(orderedWeekdaySymbols.enumerated()), id: \.offset) { _, sym in
                    Text(sym)
                        .font(DS.Font.micro)
                        .fontWeight(.semibold)
                        .foregroundStyle(DS.Colors.textTertiary)
                        .frame(width: 32, height: 20)
                }
            }

            // Day cells
            LazyVGrid(columns: gridCols, spacing: 4) {
                ForEach(Array(gridCells.enumerated()), id: \.offset) { _, day in
                    if let day {
                        CalendarDayCell(
                            day: day,
                            isSelected: cal.isDate(day, inSameDayAs: pickedDate),
                            isToday: cal.isDateInToday(day),
                            isPast: day < cal.startOfDay(for: Date()) && !cal.isDateInToday(day)
                        ) {
                            withAnimation(DS.Animation.quick) {
                                pickedDate = cal.date(
                                    bySettingHour: cal.component(.hour, from: pickedDate),
                                    minute: cal.component(.minute, from: pickedDate),
                                    second: 0,
                                    of: day
                                ) ?? day
                            }
                        }
                    } else {
                        DS.Colors.transparent.frame(width: 32, height: 32)
                    }
                }
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.bottom, DS.Spacing.sm)
    }

    private var monthHeader: some View {
        HStack(spacing: 0) {
            Button { withAnimation(DS.Animation.quick) { shiftMonth(by: -1) } } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: DS.IconSize.xs, weight: .bold))
                    .foregroundStyle(DS.Colors.textSecondary)
                    .frame(width: 32, height: 32)
                    .contentShape(Circle())
            }
            .buttonStyle(.plainPointer)

            Spacer()

            VStack(spacing: 1) {
                Text(viewMonth, format: .dateTime.month(.wide))
                    .font(DS.Font.bodySmall)
                    .fontWeight(.bold)
                    .foregroundStyle(DS.Colors.textPrimary)
                Text(viewMonth, format: .dateTime.year())
                    .font(DS.Font.small)
                    .foregroundStyle(DS.Colors.textTertiary)
            }
            .onTapGesture {
                withAnimation(DS.Animation.quick) { viewMonth = Date() }
            }
            .pointerOnHover()

            Spacer()

            Button { withAnimation(DS.Animation.quick) { shiftMonth(by: 1) } } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: DS.IconSize.xs, weight: .bold))
                    .foregroundStyle(DS.Colors.textSecondary)
                    .frame(width: 32, height: 32)
                    .contentShape(Circle())
            }
            .buttonStyle(.plainPointer)
        }
    }

    // MARK: Time

    private var timeSection: some View {
        VStack(spacing: DS.Spacing.sm) {
            // Quick time chips
            HStack(spacing: DS.Spacing.xs) {
                ForEach(quickTimes, id: \.0) { label, hour in
                    let isActive = cal.component(.hour, from: pickedDate) == hour
                        && cal.component(.minute, from: pickedDate) == 0
                    Button { setTime(hour: hour, minute: 0) } label: {
                        Text(label)
                            .font(DS.Font.small)
                            .fontWeight(isActive ? .semibold : .regular)
                            .foregroundStyle(isActive ? DS.Colors.onAccent : DS.Colors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DS.Spacing.xs)
                            .background(
                                isActive ? DS.Colors.accent : DS.Colors.fill,
                                in: RoundedRectangle(cornerRadius: DS.Radius.sm)
                            )
                    }
                    .buttonStyle(.plainPointer)
                }
            }

            // Custom time stepper
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "clock")
                    .font(.system(size: DS.IconSize.sm))
                    .foregroundStyle(DS.Colors.textTertiary)
                Text("Custom time")
                    .font(DS.Font.small)
                    .foregroundStyle(DS.Colors.textTertiary)
                Spacer()
                DatePicker("", selection: $pickedDate, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .datePickerStyle(.stepperField)
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .background(DS.Colors.fill, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.sm2)
    }

    // MARK: Actions

    private var actionsRow: some View {
        HStack(spacing: DS.Spacing.sm) {
            if existingDate != nil {
                Button("Clear") { onClear(); isPresented = false }
                    .buttonStyle(.dsSecondary)
            }
            Spacer()
            Button("Set Reminder") { onConfirm(pickedDate); isPresented = false }
                .buttonStyle(.dsPrimary)
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
    }

    // MARK: Helpers

    private var quickDates: [(String, Date)] {
        let now = Date()
        var result: [(String, Date)] = []
        if let todayAt9 = cal.date(bySettingHour: 9, minute: 0, second: 0, of: now), todayAt9 > now {
            result.append(("Today", todayAt9))
        } else {
            // Past 9am: snap to the next clean hour at least ~1h out, only if still today
            let twoHoursOut = cal.date(byAdding: .hour, value: 2, to: now) ?? now
            var comps = cal.dateComponents([.year, .month, .day, .hour], from: twoHoursOut)
            comps.minute = 0; comps.second = 0
            if let d = cal.date(from: comps), cal.isDateInToday(d) {
                result.append(("Today", d))
            }
        }
        if let tomorrow = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: now)),
           let d = cal.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow) {
            result.append(("Tomorrow", d))
        }
        if let nextWeek = cal.date(byAdding: .weekOfYear, value: 1, to: cal.startOfDay(for: now)),
           let d = cal.date(bySettingHour: 9, minute: 0, second: 0, of: nextWeek) {
            result.append(("Next week", d))
        }
        return result
    }

    private var orderedWeekdaySymbols: [String] {
        let syms = cal.veryShortStandaloneWeekdaySymbols
        let offset = cal.firstWeekday - 1
        return Array(syms[offset...] + syms[..<offset])
    }

    private var gridCells: [Date?] {
        let comps = cal.dateComponents([.year, .month], from: viewMonth)
        guard let first = cal.date(from: comps),
              let range = cal.range(of: .day, in: .month, for: first) else { return [] }
        let days: [Date?] = range.compactMap { cal.date(byAdding: .day, value: $0 - 1, to: first) }
        let blanks: [Date?] = Array(repeating: nil, count: (cal.component(.weekday, from: first) - cal.firstWeekday + 7) % 7)
        var cells = blanks + days
        while cells.count % 7 != 0 {
            cells.append(nil)
        }
        return cells
    }

    private func shiftMonth(by delta: Int) {
        if let d = cal.date(byAdding: .month, value: delta, to: viewMonth) { viewMonth = d }
    }

    private func setTime(hour: Int, minute: Int) {
        if let d = cal.date(bySettingHour: hour, minute: minute, second: 0, of: pickedDate) {
            pickedDate = d
        }
    }
}

// MARK: - Shared notification helpers (module-level, used by list and row views too)

func scheduleReminderNotification(_ reminder: Reminder, context: ModelContext) {
    guard let date = reminder.reminderDate, date > Date() else {
        if reminder.notificationScheduled {
            reminder.notificationScheduled = false
            try? context.save()
        }
        return
    }

    let center = UNUserNotificationCenter.current()
    center.getNotificationSettings { settings in
        switch settings.authorizationStatus {
        case .authorized,
             .provisional:
            _addReminderRequest(center: center, reminder: reminder, date: date, context: context)
        case .notDetermined:
            center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                guard granted else { return }
                _addReminderRequest(center: center, reminder: reminder, date: date, context: context)
            }
        default:
            break
        }
    }
}

private func _addReminderRequest(center: UNUserNotificationCenter, reminder: Reminder, date: Date, context: ModelContext) {
    center.removePendingNotificationRequests(withIdentifiers: [reminder.id.uuidString])

    let content = UNMutableNotificationContent()
    content.title = "DeepThink Reminder"
    content.body = reminder.title.isEmpty ? "You have a reminder" : reminder.title
    content.sound = .default
    content.interruptionLevel = .timeSensitive
    content.categoryIdentifier = "REMINDER"

    let cal = Calendar.current
    let components: DateComponents
    let repeats: Bool
    switch reminder.repeatInterval {
    case .none:
        components = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        repeats = false
    case .daily:
        components = cal.dateComponents([.hour, .minute], from: date)
        repeats = true
    case .weekly:
        components = cal.dateComponents([.weekday, .hour, .minute], from: date)
        repeats = true
    case .monthly:
        components = cal.dateComponents([.day, .hour, .minute], from: date)
        repeats = true
    case .yearly:
        components = cal.dateComponents([.month, .day, .hour, .minute], from: date)
        repeats = true
    }

    let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: repeats)
    let request = UNNotificationRequest(identifier: reminder.id.uuidString, content: content, trigger: trigger)

    center.add(request) { error in
        guard error == nil else { return }
        DispatchQueue.main.async {
            reminder.notificationScheduled = true
            try? context.save()
        }
    }
}

// MARK: - Calendar Day Cell

private struct CalendarDayCell: View {
    let day: Date
    let isSelected: Bool
    let isToday: Bool
    let isPast: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(
                        isSelected ? DS.Colors.accent
                            : isHovered ? DS.Colors.fillSecondary
                            : DS.Colors.transparent
                    )
                if isToday, !isSelected {
                    Circle()
                        .strokeBorder(DS.Colors.accent, lineWidth: 1.5)
                }
                Text("\(Calendar.current.component(.day, from: day))")
                    .font(DS.Font.small)
                    .fontWeight(isSelected || isToday ? .semibold : .regular)
                    .foregroundStyle(
                        isSelected ? DS.Colors.onAccent
                            : isToday ? DS.Colors.accent
                            : isPast ? DS.Colors.textTertiary.opacity(DS.Opacity.disabled)
                            : DS.Colors.textPrimary
                    )
            }
            .frame(width: 32, height: 32)
            .contentShape(Circle())
        }
        .buttonStyle(.plainPointer)
        .onHover { isHovered = $0 }
        .animation(DS.Animation.quick, value: isHovered)
    }
}
