import SwiftData
import SwiftUI

struct RecentView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Note> { !$0.isArchived }, sort: \Note.modifiedAt, order: .reverse) private var notes: [Note]
    @Query(filter: #Predicate<TaskItem> { !$0.isArchived }, sort: \TaskItem.modifiedAt, order: .reverse) private var tasks: [TaskItem]
    @Query(filter: #Predicate<Project> { !$0.isArchived }) private var projects: [Project]
    @Query(filter: #Predicate<Reminder> { !$0.isCompleted }) private var reminders: [Reminder]

    @State private var thisWeekVisibleCount = 20
    @State private var insightsRefreshID = UUID()
    @State private var showDailyBrief = false

    private var knowledge: KnowledgeService {
        KnowledgeService.shared
    }

    private var todayRemindersCount: Int {
        let startOfToday = Calendar.current.startOfDay(for: Date())
        let endOfToday = Calendar.current.date(byAdding: .day, value: 1, to: startOfToday) ?? Date()
        return reminders.count(where: { reminder in
            guard let date = reminder.reminderDate else { return false }
            return date >= startOfToday && date < endOfToday
        })
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
        let noteCount = todayItems.count(where: { $0.kind == .note })
        let taskDoneCount = todayItems.count(where: { $0.kind == .task && $0.detail == "Completed" })
        let knowledgeCount = todayItems.count(where: { $0.kind == .knowledge })

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
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        Text(greeting)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(DS.Colors.textPrimary)
                        Text(summaryLine)
                            .font(DS.Font.body)
                            .foregroundStyle(DS.Colors.textSecondary)
                    }
                    Spacer()
                    Button {
                        showDailyBrief = true
                    } label: {
                        HStack(spacing: DS.Spacing.xs) {
                            Image(systemName: "sun.horizon")
                                .font(.system(size: DS.IconSize.xs, weight: .semibold))
                            Text("Daily Brief")
                                .font(DS.Font.small)
                                .fontWeight(.semibold)
                        }
                        .foregroundStyle(DS.Colors.accent)
                        .padding(.horizontal, DS.Spacing.sm)
                        .padding(.vertical, DS.Spacing.xs)
                        .background(DS.Colors.accentFill, in: Capsule())
                    }
                    .buttonStyle(.plainPointer)
                }
                .sheet(isPresented: $showDailyBrief) {
                    DailyBriefModal(refreshID: $insightsRefreshID)
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
                        value: "\(tasks.count(where: { $0.status == .inProgress }))",
                        label: "In Progress",
                        icon: "circle.lefthalf.filled",
                        color: DS.Colors.amber
                    )
                    quickStat(
                        value: "\(tasks.count(where: { $0.isOverdue }))",
                        label: "Overdue",
                        icon: "exclamationmark.triangle",
                        color: DS.Colors.danger
                    )
                    quickStat(
                        value: "\(todayItems.count(where: { $0.kind == .task && $0.detail == "Completed" }))",
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

                if todayItems.isEmpty, yesterdayItems.isEmpty, thisWeekItems.isEmpty {
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
    var knowledgeEntryID: String?
    var isArchived: Bool = false
}

enum RecentItemKind {
    case note
    case task
    case knowledge
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

// MARK: - Agents Section

private struct ScheduleStateAgents: Codable {
    var lastRun: [String: String]
}

private struct AgentsSection: View {
    var refreshID: UUID
    var onRan: () -> Void

    private let agents: [(id: String, name: String, icon: String, hours: Int, knowledgeKey: String)] = [
        ("daily-brief", "Daily Brief", "sun.horizon", 20, "daily-brief"),
        ("stale-tasks", "Stale Task Scan", "clock.badge.exclamationmark", 168, "stale-task"),
        ("insight-scan", "Proactive Insights", "sparkles", 4, "insight")
    ]

    @State private var lastRun: [String: String] = [:]
    @State private var outputs: [String: String] = [:]
    @State private var runningAll = false

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            // Header row
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "cpu.fill")
                    .font(.system(size: DS.IconSize.xs, weight: .semibold))
                    .foregroundStyle(DS.Colors.accent)
                Text("AI Agents")
                    .font(DS.Font.small)
                    .fontWeight(.semibold)
                    .foregroundStyle(DS.Colors.textPrimary)
                Spacer()
                if runningAll {
                    ProgressView().scaleEffect(0.65)
                } else {
                    Button("Run All") { runAll() }
                        .buttonStyle(.dsSecondary)
                }
            }

            // Agent cards row
            HStack(spacing: DS.Spacing.sm) {
                ForEach(agents, id: \.id) { agent in
                    agentPill(agent)
                }
            }

            // Per-agent output cards
            ForEach(agents, id: \.id) { agent in
                if let output = outputs[agent.id], !output.isEmpty {
                    AgentOutputCard(name: agent.name, icon: agent.icon, content: output)
                }
            }
        }
        .onAppear { loadState() }
        .onChange(of: refreshID) { loadState() }
    }

    private func agentPill(_ agent: (id: String, name: String, icon: String, hours: Int, knowledgeKey: String)) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: agent.icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DS.Colors.accent)
                .frame(width: 22, height: 22)
                .background(DS.Colors.accentFill, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
            VStack(alignment: .leading, spacing: 1) {
                Text(agent.name)
                    .font(DS.Font.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(DS.Colors.textPrimary)
                Text(dueLabel(for: agent))
                    .font(DS.Font.micro)
                    .foregroundStyle(DS.Colors.textTertiary)
            }
            Spacer()
            Menu {
                Button {
                    guard !runningAll else { return }
                    runSingle(agent)
                } label: {
                    Label("Run Now", systemImage: "arrow.clockwise")
                }
                if outputs[agent.id] != nil {
                    Button(role: .destructive) {
                        outputs[agent.id] = nil
                    } label: {
                        Label("Clear Output", systemImage: "trash")
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(DS.Colors.textTertiary)
                    .frame(width: 20, height: 20)
                    .background(DS.Colors.fillSecondary, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .pointerOnHover()
            .disabled(runningAll)
        }
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.sm)
        .frame(maxWidth: .infinity)
        .background(DS.Colors.fill, in: RoundedRectangle(cornerRadius: DS.Radius.md))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).strokeBorder(DS.Colors.border, lineWidth: 1))
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private func dueLabel(for agent: (id: String, name: String, icon: String, hours: Int, knowledgeKey: String)) -> String {
        guard let lastStr = lastRun[agent.id],
              let date = Self.isoFormatter.date(from: lastStr) else { return "never" }
        let elapsed = Date().timeIntervalSince(date) / 3600
        let remaining = Double(agent.hours) - elapsed
        if remaining <= 0 { return "due" }
        return remaining < 1 ? "< 1h" : "\(Int(remaining.rounded(.up)))h"
    }

    private func runAll() {
        runningAll = true
        Task {
            await DeepThinkCLIService.shared.run(["schedule", "run", "--force"])
            await MainActor.run {
                runningAll = false
                loadState()
                onRan()
            }
        }
    }

    private func runSingle(_ agent: (id: String, name: String, icon: String, hours: Int, knowledgeKey: String)) {
        runningAll = true
        Task {
            await DeepThinkCLIService.shared.run(["schedule", "run", "--agent", agent.id, "--force"])
            await MainActor.run {
                runningAll = false
                loadState()
                onRan()
            }
        }
    }

    private func loadState() {
        let url = StorageService.shared.dataURL.appendingPathComponent("schedule-state.json")
        if let data = try? Data(contentsOf: url),
           let state = try? JSONDecoder().decode(ScheduleStateAgents.self, from: data)
        {
            lastRun = state.lastRun
        }
        loadOutputs()
    }

    private func loadOutputs() {
        let base = StorageService.shared.baseURL.appendingPathComponent("knowledge/integrations/agent")
        for agent in agents {
            let dir = base.appendingPathComponent(agent.knowledgeKey)
            guard let files = try? FileManager.default.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: [.contentModificationDateKey],
                options: .skipsHiddenFiles
            ) else { continue }
            let latest = files
                .filter { $0.pathExtension == "md" }
                .max {
                    let a = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                    let b = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                    return a < b
                }
            guard let file = latest,
                  let raw = try? String(contentsOf: file, encoding: .utf8) else { continue }
            let body = stripFrontmatter(raw)
            outputs[agent.id] = extractReadable(body)
        }
    }

    private func stripFrontmatter(_ text: String) -> String {
        var lines = text.components(separatedBy: "\n")
        if lines.first?.trimmingCharacters(in: .whitespaces) == "---" {
            lines.removeFirst()
            if let end = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "---" }) {
                lines.removeSubrange(...end)
            }
        }
        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractReadable(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // If content is a JSON object, extract "suggestion" or "result" field
        if trimmed.hasPrefix("{"), let data = trimmed.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        {
            if let s = json["suggestion"] as? String { return s }
            if let s = json["result"] as? String { return s }
            if let s = json["message"] as? String { return s }
            return ""
        }
        // If wrapped in ```json ... ```, extract the inner JSON
        if trimmed.hasPrefix("```") {
            let inner = trimmed
                .components(separatedBy: "\n")
                .dropFirst().dropLast()
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if inner.hasPrefix("{"), let data = inner.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            {
                if let s = json["suggestion"] as? String { return s }
                if let s = json["result"] as? String { return s }
                return ""
            }
        }
        return trimmed
    }
}

private struct AgentOutputCard: View {
    let name: String
    let icon: String
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: DS.IconSize.xs, weight: .semibold))
                    .foregroundStyle(DS.Colors.accent)
                    .frame(width: 24, height: 24)
                    .background(DS.Colors.accentFill, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                Text(name)
                    .font(DS.Font.small)
                    .fontWeight(.semibold)
                    .foregroundStyle(DS.Colors.textPrimary)
                Spacer()
            }
            ChatMarkdownView(markdown: content)
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.fill, in: RoundedRectangle(cornerRadius: DS.Radius.md))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).strokeBorder(DS.Colors.border, lineWidth: 1))
    }
}

// MARK: - Daily Brief Modal

private struct DailyBriefModal: View {
    @Binding var refreshID: UUID
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "sun.horizon.fill")
                        .font(.system(size: DS.IconSize.sm, weight: .semibold))
                        .foregroundStyle(Color(hue: 0.08, saturation: 0.85, brightness: 0.98))
                    Text("Daily Brief")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(DS.Colors.textPrimary)
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: DS.IconSize.xs, weight: .semibold))
                        .foregroundStyle(DS.Colors.textTertiary)
                        .frame(width: 28, height: 28)
                        .background(DS.Colors.fillSecondary, in: Circle())
                }
                .buttonStyle(.plainPointer)
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.vertical, DS.Spacing.md)

            Divider()

            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                    AgentsSection(refreshID: refreshID, onRan: { refreshID = UUID() })

                    Divider()

                    InsightsStrip(refreshID: refreshID, onRan: { refreshID = UUID() })
                }
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.vertical, DS.Spacing.lg)
            }
        }
        .frame(minWidth: 660, idealWidth: 720, minHeight: 560)
        .background(DS.Colors.surfaceElevated)
    }
}

// MARK: - Insights Strip

private struct InsightEntry: Codable, Identifiable {
    let id: String
    let severity: String
    let title: String
    let description: String
    let suggestedAction: String?
}

private struct InsightsStrip: View {
    var refreshID: UUID
    var onRan: () -> Void

    @State private var insights: [InsightEntry] = []
    @State private var isExpanded = true
    @State private var isScanning = false

    var body: some View {
        if insights.isEmpty, !isScanning { EmptyView() } else {
            VStack(spacing: 0) {
                // Header row
                Button {
                    withAnimation(DS.Animation.standard) { isExpanded.toggle() }
                } label: {
                    HStack(spacing: DS.Spacing.sm) {
                        Image(systemName: "sparkles")
                            .font(.system(size: DS.IconSize.xs, weight: .semibold))
                            .foregroundStyle(DS.Colors.accent)
                        Text("AI Insights")
                            .font(DS.Font.small)
                            .fontWeight(.semibold)
                            .foregroundStyle(DS.Colors.textPrimary)
                        if !insights.isEmpty {
                            Text("\(insights.count)")
                                .font(DS.Font.micro)
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .background(DS.Colors.fillSecondary, in: Capsule())
                                .foregroundStyle(DS.Colors.textTertiary)
                        }
                        Spacer()
                        if isScanning {
                            ProgressView().scaleEffect(0.6)
                        } else {
                            Button("Scan Now") { runScan() }
                                .buttonStyle(.dsSecondary)
                        }
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: DS.IconSize.xs, weight: .semibold))
                            .foregroundStyle(DS.Colors.textTertiary)
                    }
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.sm)
                }
                .buttonStyle(.plainPointer)

                if isExpanded, !insights.isEmpty {
                    Divider()
                    ForEach(Array(insights.enumerated()), id: \.element.id) { idx, insight in
                        if idx > 0 { Divider().padding(.leading, 40) }
                        insightRow(insight)
                    }
                }
            }
            .background(DS.Colors.fill, in: RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).strokeBorder(DS.Colors.border, lineWidth: 1))
            .animation(DS.Animation.standard, value: isExpanded)
            .onAppear { loadInsights() }
            .onChange(of: refreshID) { loadInsights() }
        }
    }

    private func insightRow(_ insight: InsightEntry) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.sm) {
            Image(systemName: severityIcon(insight.severity))
                .font(.system(size: DS.IconSize.xs, weight: .semibold))
                .foregroundStyle(severityColor(insight.severity))
                .frame(width: 20, height: 20)
                .background(severityColor(insight.severity).opacity(0.1), in: RoundedRectangle(cornerRadius: DS.Radius.sm))

            VStack(alignment: .leading, spacing: 2) {
                Text(insight.title)
                    .font(DS.Font.body)
                    .fontWeight(.medium)
                    .foregroundStyle(DS.Colors.textPrimary)
                if let action = insight.suggestedAction {
                    Text(action)
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Colors.textTertiary)
                }
            }
            Spacer()
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
    }

    private func severityIcon(_ s: String) -> String {
        switch s {
        case "action": "exclamationmark.circle.fill"
        case "warning": "exclamationmark.triangle.fill"
        default: "info.circle.fill"
        }
    }

    private func severityColor(_ s: String) -> Color {
        switch s {
        case "action": DS.Colors.danger
        case "warning": .orange
        default: DS.Colors.accent
        }
    }

    private func loadInsights() {
        let url = StorageService.shared.dataURL.appendingPathComponent("insights.json")
        guard let data = try? Data(contentsOf: url) else { insights = []; return }
        insights = (try? JSONDecoder().decode([InsightEntry].self, from: data)) ?? []
    }

    private func runScan() {
        isScanning = true
        Task {
            await DeepThinkCLIService.shared.run(["insight", "scan"])
            await MainActor.run {
                isScanning = false
                loadInsights()
                onRan()
            }
        }
    }
}
