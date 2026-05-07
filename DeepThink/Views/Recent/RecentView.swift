import SwiftUI
import SwiftData

struct RecentView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Note.modifiedAt, order: .reverse) private var notes: [Note]
    @Query(sort: \TaskItem.modifiedAt, order: .reverse) private var tasks: [TaskItem]
    @Query(filter: #Predicate<Project> { !$0.isArchived }) private var projects: [Project]
    @Query(filter: #Predicate<Reminder> { !$0.isCompleted }) private var reminders: [Reminder]

    @State private var thisWeekVisibleCount = 20

    private var knowledge: KnowledgeService { KnowledgeService.shared }

    private var todayRemindersCount: Int {
        let startOfToday = Calendar.current.startOfDay(for: Date())
        let endOfToday = Calendar.current.date(byAdding: .day, value: 1, to: startOfToday) ?? Date()
        return reminders.filter { reminder in
            guard let date = reminder.reminderDate else { return false }
            return date >= startOfToday && date < endOfToday
        }.count
    }

    private var todayItems: [RecentItem] {
        buildItems(from: Calendar.current.startOfDay(for: Date()), to: Date())
    }

    private var yesterdayItems: [RecentItem] {
        let cal = Calendar.current
        let startOfToday = cal.startOfDay(for: Date())
        let startOfYesterday = cal.date(byAdding: .day, value: -1, to: startOfToday) ?? startOfToday
        return buildItems(from: startOfYesterday, to: startOfToday)
    }

    private var thisWeekItems: [RecentItem] {
        let cal = Calendar.current
        let startOfYesterday = cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: Date())) ?? Date()
        let weekAgo = cal.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return buildItems(from: weekAgo, to: startOfYesterday)
    }

    private func buildItems(from startDate: Date, to endDate: Date) -> [RecentItem] {
        var items: [RecentItem] = []

        let recentNotes = notes.filter { $0.modifiedAt >= startDate && $0.modifiedAt < endDate }
        for note in recentNotes {
            items.append(RecentItem(
                id: "note-\(note.id)",
                icon: "doc.text",
                iconColor: DS.Colors.purple,
                title: note.title.isEmpty ? "Untitled Note" : note.title,
                subtitle: note.project?.name,
                detail: "\(note.wordCount) words",
                date: note.modifiedAt,
                kind: .note,
                entityID: note.id,
                isArchived: note.isArchived
            ))
        }

        let recentTasks = tasks.filter { $0.modifiedAt >= startDate && $0.modifiedAt < endDate && $0.parent == nil }
        for task in recentTasks {
            let action = task.status == .done ? "Completed" : (task.status == .inProgress ? "In progress" : "Updated")
            items.append(RecentItem(
                id: "task-\(task.id)",
                icon: task.status.icon,
                iconColor: task.status.color,
                title: task.title.isEmpty ? "Untitled Task" : task.title,
                subtitle: task.project?.name,
                detail: action,
                date: task.modifiedAt,
                kind: .task,
                entityID: task.id,
                isArchived: task.isArchived
            ))
        }

        let knowledgeEntries = knowledge.entries.filter { $0.importedAt >= startDate && $0.importedAt < endDate }
        for entry in knowledgeEntries {
            items.append(RecentItem(
                id: "knowledge-\(entry.id)",
                icon: entry.sourceIcon,
                iconColor: DS.Colors.teal,
                title: entry.title,
                subtitle: entry.bucket,
                detail: entry.formattedSize,
                date: entry.importedAt,
                kind: .knowledge,
                entityID: nil,
                knowledgeEntryID: entry.id
            ))
        }

        return items.sorted { $0.date > $1.date }
    }

    private var summaryLine: String {
        let todayCount = todayItems.count
        let noteCount = todayItems.filter { $0.kind == .note }.count
        let taskDoneCount = todayItems.filter { $0.kind == .task && $0.detail == "Completed" }.count
        let knowledgeCount = todayItems.filter { $0.kind == .knowledge }.count

        var parts: [String] = []
        if noteCount > 0 { parts.append("\(noteCount) note\(noteCount == 1 ? "" : "s") edited") }
        if taskDoneCount > 0 { parts.append("\(taskDoneCount) task\(taskDoneCount == 1 ? "" : "s") done") }
        if knowledgeCount > 0 { parts.append("\(knowledgeCount) item\(knowledgeCount == 1 ? "" : "s") saved") }

        if parts.isEmpty { return "No activity today yet" }
        return "Today: " + parts.joined(separator: ", ")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                // Header
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(greeting)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(DS.Colors.textPrimary)
                    Text(summaryLine)
                        .font(DS.Font.body)
                        .foregroundStyle(DS.Colors.textSecondary)
                }

                // Quick stats
                HStack(spacing: DS.Spacing.md) {
                    quickStat(
                        value: "\(projects.count)",
                        label: "Projects",
                        icon: "folder",
                        color: DS.Colors.accent
                    )
                    quickStat(
                        value: "\(tasks.filter { $0.status == .inProgress }.count)",
                        label: "In Progress",
                        icon: "circle.lefthalf.filled",
                        color: DS.Colors.amber
                    )
                    quickStat(
                        value: "\(tasks.filter { $0.isOverdue }.count)",
                        label: "Overdue",
                        icon: "exclamationmark.triangle",
                        color: DS.Colors.danger
                    )
                    quickStat(
                        value: "\(todayItems.filter { $0.kind == .task && $0.detail == "Completed" }.count)",
                        label: "Done Today",
                        icon: "checkmark.circle",
                        color: DS.Colors.success
                    )
                    quickStat(
                        value: "\(todayRemindersCount)",
                        label: "Reminders",
                        icon: "bell",
                        color: DS.Colors.purple
                    )
                }

                // Timeline sections
                if !todayItems.isEmpty {
                    timelineSection(title: "Today", items: todayItems)
                }

                if !yesterdayItems.isEmpty {
                    timelineSection(title: "Yesterday", items: yesterdayItems)
                }

                if !thisWeekItems.isEmpty {
                    timelineSection(
                        title: "This Week",
                        items: thisWeekItems,
                        visibleLimit: thisWeekVisibleCount,
                        onViewMore: { thisWeekVisibleCount += 20 }
                    )
                }

                if todayItems.isEmpty && yesterdayItems.isEmpty && thisWeekItems.isEmpty {
                    DSEmptyState(
                        icon: "clock.arrow.circlepath",
                        title: "No Recent Activity",
                        subtitle: "Start by creating a note, adding a task, or saving knowledge. Your activity will show up here."
                    )
                }
            }
            .padding(DS.Spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        let dateStr = formatter.string(from: Date())
        let timeOfDay = hour < 12 ? "Good morning" : (hour < 17 ? "Good afternoon" : "Good evening")
        return "\(timeOfDay) — \(dateStr)"
    }

    @ViewBuilder
    private func quickStat(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: DS.IconSize.sm, weight: .medium))
                    .foregroundStyle(color)
                Text(value)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(DS.Colors.textPrimary)
            }
            Text(label)
                .font(DS.Font.small)
                .foregroundStyle(DS.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(DS.Spacing.md)
        .background(
            LinearGradient(
                colors: [color.opacity(0.06), color.opacity(0.02)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: DS.Radius.md)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .strokeBorder(color.opacity(0.12), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func timelineSection(
        title: String,
        items: [RecentItem],
        visibleLimit: Int? = nil,
        onViewMore: (() -> Void)? = nil
    ) -> some View {
        let visibleItems = visibleLimit.map { Array(items.prefix($0)) } ?? items
        let hasMore = visibleLimit.map { $0 < items.count } ?? false

        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.sm) {
                Text(title)
                    .font(DS.Font.heading)
                    .foregroundStyle(DS.Colors.textPrimary)
                DSPill(text: "\(items.count)", color: DS.Colors.textTertiary)
                Spacer()
            }

            VStack(spacing: 0) {
                ForEach(Array(visibleItems.enumerated()), id: \.element.id) { index, item in
                    RecentItemRow(item: item) {
                        navigateTo(item)
                    }

                    if index < visibleItems.count - 1 || hasMore {
                        Divider()
                    }
                }

                if hasMore, let onViewMore {
                    Button(action: onViewMore) {
                        HStack(spacing: DS.Spacing.sm) {
                            Image(systemName: "chevron.down")
                                .font(.system(size: DS.IconSize.xs, weight: .semibold))
                            Text("View More")
                                .font(DS.Font.body)
                                .fontWeight(.medium)
                            Text("(\(items.count - visibleItems.count) remaining)")
                                .font(DS.Font.small)
                                .foregroundStyle(DS.Colors.textTertiary)
                        }
                        .foregroundStyle(DS.Colors.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.sm + 2)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plainPointer)
                }
            }
            .background(DS.Colors.surface, in: RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .strokeBorder(DS.Colors.border, lineWidth: 1)
            )
        }
    }

    private func navigateTo(_ item: RecentItem) {
        switch item.kind {
        case .note:
            guard let id = item.entityID else { return }
            appState.navigateToNote(id)
        case .task:
            guard let id = item.entityID else { return }
            appState.navigateToTask(id)
        case .knowledge:
            guard let entryID = item.knowledgeEntryID else { return }
            appState.navigateToKnowledgeEntry(entryID)
        }
    }
}

// MARK: - Models

struct RecentItem: Identifiable {
    let id: String
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String?
    let detail: String
    let date: Date
    let kind: RecentItemKind
    let entityID: UUID?
    var knowledgeEntryID: String? = nil
    var isArchived: Bool = false
}

enum RecentItemKind {
    case note, task, knowledge
}

// MARK: - Row

private struct RecentItemRow: View {
    let item: RecentItem
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: DS.Radius.sm)
                        .fill(item.iconColor.opacity(0.1))
                        .frame(width: 32, height: 32)
                    Image(systemName: item.icon)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(item.iconColor)
                }

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(item.title)
                        .font(DS.Font.body)
                        .fontWeight(.medium)
                        .foregroundStyle(DS.Colors.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: DS.Spacing.sm) {
                        if let subtitle = item.subtitle {
                            Text(subtitle)
                                .font(DS.Font.small)
                                .foregroundStyle(DS.Colors.accent)
                        }
                        Text(item.detail)
                            .font(DS.Font.small)
                            .foregroundStyle(DS.Colors.textTertiary)
                    }
                }

                Spacer()

                Text(item.date.relativeFormatted)
                    .font(DS.Font.small)
                    .foregroundStyle(DS.Colors.textTertiary)

                if item.isArchived {
                    Image(systemName: "archivebox")
                        .font(.system(size: DS.IconSize.xs, weight: .medium))
                        .foregroundStyle(DS.Colors.textTertiary)
                }

                kindBadge
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm + 2)
            .background(isHovered ? DS.Colors.fillSecondary : .clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plainPointer)
        .onHover { isHovered = $0 }
        .animation(DS.Animation.quick, value: isHovered)
    }

    @ViewBuilder
    private var kindBadge: some View {
        Text(item.kind.label)
            .font(.system(size: DS.IconSize.xs, weight: .medium))
            .foregroundStyle(item.kind.badgeColor)
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xxs)
            .background(item.kind.badgeColor.opacity(0.1), in: Capsule())
    }
}

extension RecentItemKind {
    var label: String {
        switch self {
        case .note: "Note"
        case .task: "Task"
        case .knowledge: "Knowledge"
        }
    }

    var badgeColor: Color {
        switch self {
        case .note: DS.Colors.purple
        case .task: DS.Colors.amber
        case .knowledge: DS.Colors.teal
        }
    }
}
