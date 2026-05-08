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

    enum FilterMode: String, CaseIterable {
        case active = "Active"
        case upcoming = "Upcoming"
        case overdue = "Overdue"
        case completed = "Completed"
        case all = "All"
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

        ResizableSplitView(minLeftWidth: 240, minRightWidth: 400) {
            listPane
        } right: {
            if let selectedID = appState.selectedReminderID,
               let reminder = allReminders.first(where: { $0.id == selectedID })
            {
                ReminderDetailView(reminder: reminder)
                    .id(reminder.id)
            } else {
                VStack(spacing: DS.Spacing.md) {
                    Image(systemName: "bell")
                        .font(.system(size: 40))
                        .foregroundStyle(DS.Colors.textTertiary)
                    Text("Select a reminder")
                        .font(DS.Font.body)
                        .foregroundStyle(DS.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                        Button {
                            filterMode = filter
                        } label: {
                            Text(filter.rawValue)
                                .font(DS.Font.small)
                                .fontWeight(filterMode == filter ? .semibold : .regular)
                                .foregroundStyle(filterMode == filter ? DS.Colors.accent : DS.Colors.textSecondary)
                                .padding(.horizontal, DS.Spacing.sm)
                                .padding(.vertical, DS.Spacing.xs)
                                .background(filterMode == filter ? DS.Colors.accentFill : DS.Colors.fill, in: Capsule())
                                .overlay(Capsule().strokeBorder(filterMode == filter ? DS.Colors.accent.opacity(0.3) : DS.Colors.border, lineWidth: 1))
                        }
                        .buttonStyle(.plainPointer)
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
            }
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

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredReminders) { reminder in
                        let isSelected = appState.selectedReminderID == reminder.id
                        Button {
                            appState.selectedReminderID = reminder.id
                        } label: {
                            ReminderRowView(reminder: reminder)
                                .padding(.horizontal, DS.Spacing.sm)
                                .padding(.vertical, DS.Spacing.xxs)
                                .background(isSelected ? DS.Colors.accentFill : .clear)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plainPointer)
                        .contextMenu {
                            Button(reminder.isCompleted ? "Mark Active" : "Mark Completed") {
                                toggleCompletion(reminder)
                            }
                            Divider()
                            Button("Delete", role: .destructive) { deleteReminder(reminder) }
                        }
                        if reminder.id != filteredReminders.last?.id {
                            Divider()
                        }
                    }
                }
            }
            .overlay {
                if filteredReminders.isEmpty {
                    DSEmptyState(
                        icon: "bell",
                        title: "No Reminders Yet",
                        subtitle: "Keep track of things you need to remember. Set a date and time to get notified.",
                        hint: "Reminders can have an optional time alert",
                        action: createReminder,
                        actionTitle: "New Reminder"
                    )
                }
            }
        }
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
    }
}
