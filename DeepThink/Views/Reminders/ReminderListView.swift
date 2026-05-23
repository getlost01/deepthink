import SwiftData
import SwiftUI
import UserNotifications

struct ReminderListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Query(sort: \Reminder.createdAt, order: .reverse) private var allReminders: [Reminder]
    @State private var searchText = ""
    @State private var debouncedSearch = ""
    @State private var searchTask: Task<Void, Never>?
    @State private var filterMode: FilterMode = .active
    @State private var priorityFilter: PriorityFilter = .all
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @FocusState private var listFocused: Bool

    enum FilterMode: String, CaseIterable {
        case active = "Active"
        case upcoming = "Upcoming"
        case overdue = "Overdue"
        case completed = "Completed"
        case all = "All"
    }

    enum PriorityFilter: String, CaseIterable {
        case all = "All"
        case high = "High"
        case medium = "Med"
        case low = "Low"
    }

    private var filteredReminders: [Reminder] {
        var items = allReminders

        switch filterMode {
        case .active:
            items = items.filter { !$0.isCompleted }
        case .upcoming:
            items = items.filter(\.isPending)
        case .overdue:
            items = items.filter(\.isOverdue)
        case .completed:
            items = items.filter(\.isCompleted)
        case .all:
            break
        }

        switch priorityFilter {
        case .high: items = items.filter { $0.priority == .high }
        case .medium: items = items.filter { $0.priority == .medium }
        case .low: items = items.filter { $0.priority == .low }
        case .all: break
        }

        if !debouncedSearch.isEmpty {
            let lowered = debouncedSearch.lowercased()
            items = items.filter { $0.title.lowercased().contains(lowered) || $0.notes.lowercased().contains(lowered) }
        }

        return items.sorted { a, b in
            if a.isCompleted != b.isCompleted { return !a.isCompleted }
            if let ad = a.reminderDate, let bd = b.reminderDate { return ad < bd }
            if a.reminderDate != nil { return true }
            if b.reminderDate != nil { return false }
            return a.createdAt > b.createdAt
        }
    }

    var body: some View {
        @Bindable var appState = appState

        VStack(spacing: 0) {
            if notificationStatus == .denied {
                NotificationPermissionBanner(isDenied: true, onEnable: {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.notifications")!)
                })
                Divider()
            } else if notificationStatus == .notDetermined {
                NotificationPermissionBanner(isDenied: false, onEnable: {
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
                        DispatchQueue.main.async { checkNotificationStatus() }
                    }
                })
                Divider()
            }

            ResizableSplitView(minLeftWidth: 240, minRightWidth: 400) {
                listPane
            } right: {
                if let selectedID = appState.selectedReminderID,
                   let reminder = allReminders.first(where: { $0.id == selectedID }) {
                    ReminderDetailView(reminder: reminder)
                        .id(reminder.id)
                } else {
                    DSEmptyState(
                        icon: "bell",
                        title: "Select a Reminder",
                        subtitle: "Pick a reminder from the list to see details, or create a new one.",
                        hint: "Tip: set a date and time to get a native macOS notification",
                        action: createReminder,
                        actionTitle: "New Reminder"
                    )
                }
            }
        }
        .onChange(of: searchText) {
            searchTask?.cancel()
            searchTask = Task {
                try? await Task.sleep(for: .milliseconds(200))
                guard !Task.isCancelled else { return }
                debouncedSearch = searchText
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .createNewReminder)) { _ in
            createReminder()
        }
        .onAppear {
            checkNotificationStatus()
            validateNotificationFlags()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            checkNotificationStatus()
            validateNotificationFlags()
        }
    }

    private var listPane: some View {
        VStack(spacing: 0) {
            HStack(spacing: DS.Spacing.sm) {
                DSSearchField(text: $searchText, placeholder: "Search reminders...")
                DSAddButton {
                    createReminder()
                }
                .help("New Reminder")
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.sm)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Spacing.xs) {
                    ForEach(FilterMode.allCases, id: \.self) { filter in
                        filterChip(filter.rawValue, isActive: filterMode == filter) { filterMode = filter }
                    }
                    Divider()
                        .frame(height: 16)
                        .padding(.horizontal, DS.Spacing.xxs)
                    ForEach(PriorityFilter.allCases, id: \.self) { pf in
                        let pfColor: Color = pf == .high ? DS.Colors.danger : pf == .medium ? DS.Colors.warning : pf == .low ? DS.Colors.success : DS.Colors
                            .textSecondary
                        filterChip(pf.rawValue, isActive: priorityFilter == pf, activeColor: pf == .all ? DS.Colors.accent : pfColor) { priorityFilter = pf }
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
            }
            .mask(
                HStack(spacing: 0) {
                    Rectangle().frame(maxWidth: .infinity)
                    LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                        .frame(width: DS.Spacing.xl)
                }
            )
            .padding(.bottom, DS.Spacing.sm)

            if !allReminders.isEmpty {
                let done = allReminders.filter(\.isCompleted).count
                let total = allReminders.count
                HStack(spacing: DS.Spacing.sm) {
                    ProgressView(value: Double(done) / Double(total))
                        .tint(DS.Colors.accent)
                    Text("\(done)/\(total)")
                        .font(DS.Font.small)
                        .foregroundStyle(DS.Colors.textTertiary)
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.xs)
            }

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredReminders) { reminder in
                            let isSelected = appState.selectedReminderID == reminder.id
                            Button {
                                appState.selectedReminderID = reminder.id
                                listFocused = true
                            } label: {
                                ReminderRowView(reminder: reminder)
                                    .padding(.horizontal, DS.Spacing.sm)
                                    .padding(.vertical, DS.Spacing.xxs)
                                    .background(isSelected ? DS.Colors.accentFill : .clear)
                                    .contentShape(Rectangle())
                            }
                            .id(reminder.id)
                            .buttonStyle(.plainPointer)
                            .contextMenu {
                                Button {
                                    toggleCompletion(reminder)
                                } label: {
                                    Label(reminder.isCompleted ? "Mark Active" : "Mark Completed", systemImage: reminder.isCompleted ? "circle" : "checkmark.circle.fill")
                                }
                                Divider()
                                Button(role: .destructive) { deleteReminder(reminder) } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            if reminder.id != filteredReminders.last?.id {
                                Divider()
                            }
                        }
                    }
                }
                .focusable()
                .focused($listFocused)
                .focusEffectDisabled()
                .onKeyPress(.upArrow) { navigateList(by: -1, proxy: proxy); return .handled }
                .onKeyPress(.downArrow) { navigateList(by: 1, proxy: proxy); return .handled }
                .overlay {
                    if filteredReminders.isEmpty {
                        if allReminders.isEmpty {
                            DSEmptyState(
                                icon: "bell",
                                title: "No Reminders Yet",
                                subtitle: "Keep track of things you need to remember. Set a date and time to get notified.",
                                hint: "Reminders can have an optional time alert",
                                action: createReminder,
                                actionTitle: "New Reminder"
                            )
                        } else {
                            DSEmptyState(
                                icon: "line.3.horizontal.decrease.circle",
                                title: "No Matches",
                                subtitle: "No reminders match the current filters.",
                                action: { filterMode = .active; priorityFilter = .all; searchText = "" },
                                actionTitle: "Clear Filters"
                            )
                        }
                    }
                }
            }
        }
    }

    private func navigateList(by delta: Int, proxy: ScrollViewProxy) {
        guard !filteredReminders.isEmpty else { return }
        if let current = appState.selectedReminderID,
           let idx = filteredReminders.firstIndex(where: { $0.id == current }) {
            let newIdx = max(0, min(filteredReminders.count - 1, idx + delta))
            let newID = filteredReminders[newIdx].id
            appState.selectedReminderID = newID
            proxy.scrollTo(newID, anchor: .center)
        } else {
            let target = delta > 0 ? filteredReminders.first : filteredReminders.last
            appState.selectedReminderID = target?.id
            if let id = target?.id { proxy.scrollTo(id, anchor: .center) }
        }
    }

    private func filterChip(_ label: String, isActive: Bool, activeColor: Color = DS.Colors.accent, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(DS.Font.small)
                .fontWeight(isActive ? .semibold : .regular)
                .foregroundStyle(isActive ? activeColor : DS.Colors.textSecondary)
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.vertical, DS.Spacing.xs)
                .background(isActive ? activeColor.opacity(0.12) : DS.Colors.fill, in: Capsule())
                .overlay(Capsule().strokeBorder(isActive ? activeColor.opacity(0.3) : DS.Colors.border, lineWidth: 1))
        }
        .buttonStyle(.plainPointer)
    }

    private func createReminder() {
        let reminder = Reminder(title: "New Reminder")
        modelContext.insert(reminder)
        appState.selectedReminderID = reminder.id
    }

    private func deleteReminder(_ reminder: Reminder) {
        cancelNotification(for: reminder)
        if appState.selectedReminderID == reminder.id { appState.selectedReminderID = nil }
        modelContext.delete(reminder)
    }

    private func toggleCompletion(_ reminder: Reminder) {
        reminder.isCompleted.toggle()
        reminder.completedAt = reminder.isCompleted ? Date() : nil
        reminder.modifiedAt = Date()
        if reminder.isCompleted {
            cancelNotification(for: reminder)
        }
        try? modelContext.save()
    }

    private func cancelNotification(for reminder: Reminder) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [reminder.id.uuidString]
        )
        reminder.notificationScheduled = false
        try? modelContext.save()
    }

    private func checkNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                notificationStatus = settings.authorizationStatus
            }
        }
    }

    private func validateNotificationFlags() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let pendingIDs = Set(requests.map(\.identifier))
            DispatchQueue.main.async {
                var changed = false
                for reminder in allReminders {
                    let stillPending = pendingIDs.contains(reminder.id.uuidString)
                    if reminder.notificationScheduled, !stillPending {
                        reminder.notificationScheduled = false
                        changed = true
                    }
                    if stillPending, reminder.repeatInterval != .none,
                       let date = reminder.reminderDate, date < Date() {
                        reminder.reminderDate = nextOccurrence(after: Date(), from: date, interval: reminder.repeatInterval)
                        reminder.modifiedAt = Date()
                        changed = true
                    }
                }
                if changed { try? modelContext.save() }
            }
        }
    }

    private func nextOccurrence(after now: Date, from original: Date, interval: ReminderRepeat) -> Date? {
        let cal = Calendar.current
        var next = original
        while next <= now {
            switch interval {
            case .none: return nil
            case .daily: next = cal.date(byAdding: .day, value: 1, to: next) ?? next
            case .weekly: next = cal.date(byAdding: .weekOfYear, value: 1, to: next) ?? next
            case .monthly: next = cal.date(byAdding: .month, value: 1, to: next) ?? next
            case .yearly: next = cal.date(byAdding: .year, value: 1, to: next) ?? next
            }
        }
        return next
    }
}

private struct NotificationPermissionBanner: View {
    let isDenied: Bool
    let onEnable: () -> Void

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "bell.slash.fill")
                .font(.system(size: DS.IconSize.sm, weight: .medium))
                .foregroundStyle(DS.Colors.warning)
                .frame(width: 22, height: 22)
                .background(DS.Colors.warning.opacity(0.12), in: RoundedRectangle(cornerRadius: DS.Radius.sm))

            HStack(spacing: DS.Spacing.xs) {
                Text(isDenied ? "Notifications Disabled" : "Notifications Not Enabled")
                    .font(DS.Font.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(DS.Colors.textPrimary)
                Text("(reminders won't alert you)")
                    .font(DS.Font.small)
                    .foregroundStyle(DS.Colors.textTertiary)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                onEnable()
            } label: {
                Text(isDenied ? "Open Settings" : "Enable Notifications")
                    .font(DS.Font.small)
                    .fontWeight(.semibold)
                    .foregroundStyle(DS.Colors.warning)
                    .frame(height: 20)
                    .padding(.horizontal, DS.Spacing.xs2)
                    .background(DS.Colors.warning.opacity(0.12), in: RoundedRectangle(cornerRadius: DS.Radius.sm))
            }
            .buttonStyle(.plainPointer)
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.Colors.fill)
    }
}
