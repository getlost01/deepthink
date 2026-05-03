import SwiftUI
import SwiftData

struct KnowledgeTimelineView: View {
    @Query(sort: \Note.modifiedAt, order: .reverse) private var notes: [Note]
    @State private var isGeneratingDigest = false
    @State private var digestContent: String?

    private var knowledge: KnowledgeService { KnowledgeService.shared }

    private var recentEntries: [KnowledgeEntry] {
        knowledge.entries
            .sorted { $0.importedAt > $1.importedAt }
            .prefix(20)
            .map { $0 }
    }

    private var recentNotes: [Note] {
        Array(notes.prefix(10))
    }

    private var todayEntries: [KnowledgeEntry] {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        return recentEntries.filter { $0.importedAt >= startOfDay }
    }

    private var thisWeekEntries: [KnowledgeEntry] {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let startOfDay = Calendar.current.startOfDay(for: Date())
        return recentEntries.filter { $0.importedAt >= weekAgo && $0.importedAt < startOfDay }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                HStack {
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        Text("What's New")
                            .font(DS.Font.title)
                            .foregroundStyle(DS.Colors.textPrimary)
                        Text("Recent knowledge and activity")
                            .font(DS.Font.caption)
                            .foregroundStyle(DS.Colors.textSecondary)
                    }

                    Spacer()

                    Button {
                        generateDigest()
                    } label: {
                        HStack(spacing: DS.Spacing.xs) {
                            if isGeneratingDigest {
                                ProgressView().controlSize(.mini)
                            } else {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 10))
                            }
                            Text("AI Digest")
                                .font(DS.Font.small)
                                .fontWeight(.medium)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, DS.Spacing.md)
                        .padding(.vertical, DS.Spacing.sm)
                        .background(DS.Colors.accent, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                    }
                    .buttonStyle(.plainPointer)
                    .disabled(isGeneratingDigest)
                }

                if let digest = digestContent {
                    DSCard {
                        VStack(alignment: .leading, spacing: DS.Spacing.md) {
                            HStack {
                                Image(systemName: "sparkles")
                                    .foregroundStyle(DS.Colors.accent)
                                Text("AI Digest")
                                    .font(DS.Font.heading)
                                Spacer()
                                DSToolbarButton(icon: "xmark", color: DS.Colors.textTertiary, size: DS.IconSize.sm) {
                                    digestContent = nil
                                }
                            }
                            Text(digest)
                                .font(DS.Font.body)
                                .foregroundStyle(DS.Colors.textPrimary)
                                .textSelection(.enabled)
                        }
                    }
                }

                HStack(spacing: DS.Spacing.md) {
                    StatBox(value: "\(knowledge.entries.count)", label: "Total Entries", icon: "book", color: .blue)
                    StatBox(value: "\(todayEntries.count)", label: "Today", icon: "sun.max", color: .orange)
                    StatBox(value: "\(thisWeekEntries.count)", label: "This Week", icon: "calendar", color: .green)
                    StatBox(value: "\(recentNotes.count)", label: "Active Notes", icon: "doc.text", color: .purple)
                }

                if !todayEntries.isEmpty {
                    TimelineSection(title: "Today", entries: todayEntries)
                }

                if !thisWeekEntries.isEmpty {
                    TimelineSection(title: "This Week", entries: thisWeekEntries)
                }

                if !recentNotes.isEmpty {
                    VStack(alignment: .leading, spacing: DS.Spacing.md) {
                        DSSectionHeader(title: "Recently Modified Notes")

                        VStack(spacing: 0) {
                            ForEach(recentNotes.prefix(5)) { note in
                                HStack(spacing: DS.Spacing.md) {
                                    Image(systemName: "doc.text")
                                        .font(.system(size: DS.IconSize.sm))
                                        .foregroundStyle(DS.Colors.textTertiary)
                                        .frame(width: 20)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(note.title.isEmpty ? "Untitled" : note.title)
                                            .font(DS.Font.body)
                                            .foregroundStyle(DS.Colors.textPrimary)
                                            .lineLimit(1)
                                        Text("\(note.wordCount) words • \(note.modifiedAt, style: .relative) ago")
                                            .font(DS.Font.small)
                                            .foregroundStyle(DS.Colors.textTertiary)
                                    }

                                    Spacer()

                                    let linked = BacklinkService.shared.knowledgeEntriesLinkedTo(note: note)
                                    if !linked.isEmpty {
                                        HStack(spacing: DS.Spacing.xs) {
                                            Image(systemName: "link")
                                                .font(.system(size: 8))
                                            Text("\(linked.count)")
                                                .font(DS.Font.small)
                                        }
                                        .foregroundStyle(DS.Colors.accent)
                                        .padding(.horizontal, DS.Spacing.sm)
                                        .padding(.vertical, 2)
                                        .background(DS.Colors.accentFill, in: Capsule())
                                    }
                                }
                                .padding(.vertical, DS.Spacing.sm)

                                if note.id != recentNotes.prefix(5).last?.id {
                                    Divider()
                                }
                            }
                        }
                        .padding(DS.Spacing.md)
                        .background(DS.Colors.fillSecondary, in: RoundedRectangle(cornerRadius: DS.Radius.md))
                    }
                }

                if recentEntries.isEmpty && recentNotes.isEmpty {
                    DSEmptyState(
                        icon: "sparkles",
                        title: "No Activity Yet",
                        subtitle: "Add knowledge entries or create notes to see your timeline."
                    )
                }
            }
            .padding(DS.Spacing.xl)
        }
        .onAppear { knowledge.reload() }
    }

    private func generateDigest() {
        isGeneratingDigest = true
        Task {
            var summary: [String] = []

            if !todayEntries.isEmpty {
                summary.append("Today's entries:\n" + todayEntries.map { "- \($0.title) (\($0.source))" }.joined(separator: "\n"))
            }
            if !recentNotes.isEmpty {
                summary.append("Recent notes:\n" + recentNotes.prefix(5).map { "- \($0.title) (\($0.wordCount) words)" }.joined(separator: "\n"))
            }
            if !thisWeekEntries.isEmpty {
                summary.append("This week's entries:\n" + thisWeekEntries.prefix(10).map { "- \($0.title)" }.joined(separator: "\n"))
            }

            guard !summary.isEmpty else {
                await MainActor.run {
                    digestContent = "No recent activity to summarize."
                    isGeneratingDigest = false
                }
                return
            }

            do {
                let result = try await ClaudeService.shared.query(
                    "Generate a brief daily digest from this workspace activity. Highlight key themes, connections between items, and suggest what to focus on next.\n\n\(summary.joined(separator: "\n\n"))",
                    systemPrompt: "You are a workspace digest generator. Be concise — 3-5 bullet points max. Identify patterns and suggest priorities."
                )
                await MainActor.run {
                    digestContent = result
                    isGeneratingDigest = false
                }
            } catch {
                await MainActor.run {
                    digestContent = "Failed to generate digest: \(error.localizedDescription)"
                    isGeneratingDigest = false
                }
            }
        }
    }
}

// MARK: - Timeline Section

private struct TimelineSection: View {
    let title: String
    let entries: [KnowledgeEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            DSSectionHeader(title: title)

            VStack(spacing: 0) {
                ForEach(entries) { entry in
                    HStack(spacing: DS.Spacing.md) {
                        Image(systemName: entry.sourceIcon)
                            .font(.system(size: DS.IconSize.sm))
                            .foregroundStyle(DS.Colors.textTertiary)
                            .frame(width: 20)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.title)
                                .font(DS.Font.body)
                                .foregroundStyle(DS.Colors.textPrimary)
                                .lineLimit(1)
                            HStack(spacing: DS.Spacing.sm) {
                                Text(entry.source)
                                    .font(DS.Font.small)
                                    .foregroundStyle(DS.Colors.textTertiary)
                                if !entry.tags.isEmpty {
                                    Text(entry.tags.prefix(3).joined(separator: ", "))
                                        .font(DS.Font.small)
                                        .foregroundStyle(DS.Colors.accent)
                                }
                            }
                        }

                        Spacer()

                        Text(entry.importedAt, style: .relative)
                            .font(DS.Font.small)
                            .foregroundStyle(DS.Colors.textTertiary)
                    }
                    .padding(.vertical, DS.Spacing.sm)

                    if entry.id != entries.last?.id {
                        Divider()
                    }
                }
            }
            .padding(DS.Spacing.md)
            .background(DS.Colors.fillSecondary, in: RoundedRectangle(cornerRadius: DS.Radius.md))
        }
    }
}

// MARK: - Stat Box

private struct StatBox: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: DS.IconSize.sm, weight: .medium))
                    .foregroundStyle(color)
                Text(label)
                    .font(DS.Font.small)
                    .foregroundStyle(DS.Colors.textTertiary)
                    .textCase(.uppercase)
            }
            Text(value)
                .font(DS.Font.title)
                .foregroundStyle(DS.Colors.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(DS.Spacing.md)
        .background(DS.Colors.fillSecondary, in: RoundedRectangle(cornerRadius: DS.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .strokeBorder(DS.Colors.border, lineWidth: 1)
        )
    }
}
