import SwiftUI
import SwiftData

struct DeepSearchView: View {
    @Environment(AppState.self) private var appState
    @Query private var notes: [Note]
    @Query private var tasks: [TaskItem]
    @Query private var projects: [Project]

    @State private var query = ""
    @State private var isSearching = false
    @State private var aiResult: String?
    @State private var searchMode: SearchMode = .workspace
    @FocusState private var focused: Bool

    enum SearchMode: String, CaseIterable {
        case workspace = "Workspace"
        case ai = "AI Search"
    }

    private var localResults: [SearchResult] {
        guard !query.isEmpty else { return [] }
        let q = query.lowercased()
        var results: [SearchResult] = []

        for note in notes {
            if note.title.lowercased().contains(q) || note.content.lowercased().contains(q) {
                let snippet = extractSnippet(from: note.content, matching: q)
                results.append(SearchResult(type: .note, title: note.title.isEmpty ? "Untitled" : note.title, subtitle: snippet, id: note.id))
            }
        }
        for task in tasks {
            if task.title.lowercased().contains(q) || task.detail.lowercased().contains(q) {
                results.append(SearchResult(type: .task, title: task.title, subtitle: "[\(task.status.rawValue)] \(task.detail.prefix(80))", id: task.id))
            }
        }
        for project in projects {
            if project.name.lowercased().contains(q) || project.summary.lowercased().contains(q) {
                results.append(SearchResult(type: .project, title: project.name, subtitle: project.summary.prefix(80).description, id: project.id))
            }
        }
        let knowledgeResults = KnowledgeService.shared.search(q)
        for item in knowledgeResults.prefix(10) {
            results.append(SearchResult(type: .context, title: item.title, subtitle: String(item.content.prefix(100)), id: UUID()))
        }

        return results
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: DS.Spacing.md) {
                HStack(spacing: DS.Spacing.md) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: DS.IconSize.md))
                        .foregroundStyle(DS.Colors.textTertiary)

                    TextField("Search your knowledge base...", text: $query)
                        .textFieldStyle(.plain)
                        .font(DS.Font.heading)
                        .focused($focused)
                        .onSubmit { performSearch() }

                    if isSearching {
                        ProgressView().scaleEffect(0.7)
                    }

                    if !query.isEmpty {
                        Button {
                            query = ""
                            aiResult = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: DS.IconSize.md))
                                .foregroundStyle(DS.Colors.textTertiary)
                        }
                        .buttonStyle(.plainPointer)
                    }
                }
                .dsInputField()

                HStack(spacing: DS.Spacing.sm) {
                    ForEach(SearchMode.allCases, id: \.self) { mode in
                        Button {
                            searchMode = mode
                            aiResult = nil
                        } label: {
                            Text(mode.rawValue)
                                .font(DS.Font.small)
                                .fontWeight(searchMode == mode ? .semibold : .regular)
                                .foregroundStyle(searchMode == mode ? DS.Colors.onAccent : DS.Colors.textSecondary)
                                .padding(.horizontal, DS.Spacing.lg)
                                .padding(.vertical, DS.Spacing.sm)
                                .background(searchMode == mode ? DS.Colors.accent : DS.Colors.fill, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                        }
                        .buttonStyle(.plainPointer)
                    }
                }
            }
            .padding(DS.Spacing.xl)
            .background(DS.Colors.surfaceElevated)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    if let aiResult, !aiResult.isEmpty {
                        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                            HStack(spacing: DS.Spacing.sm) {
                                Text("AI Analysis")
                                    .font(DS.Font.heading)
                                Spacer()
                                DSToolbarButton(icon: "doc.on.doc", color: DS.Colors.textTertiary, size: DS.IconSize.sm) {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(aiResult, forType: .string)
                                }
                            }

                            if let attributed = try? AttributedString(markdown: aiResult, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
                                Text(attributed)
                                    .font(DS.Font.body)
                                    .textSelection(.enabled)
                            } else {
                                Text(aiResult)
                                    .font(DS.Font.body)
                                    .textSelection(.enabled)
                            }
                        }
                        .padding(DS.Spacing.lg)
                        .dsBordered()
                    }

                    if !localResults.isEmpty {
                        Text("Workspace Results (\(localResults.count))")
                            .font(DS.Font.heading)

                        ForEach(localResults) { result in
                            SearchResultRow(result: result) {
                                navigateTo(result)
                            }
                        }
                    }

                    if query.isEmpty && aiResult == nil {
                        VStack(spacing: DS.Spacing.xl) {
                            Image(systemName: "sparkle.magnifyingglass")
                                .font(.system(size: 36, weight: .light))
                                .foregroundStyle(DS.Colors.textTertiary)
                            VStack(spacing: DS.Spacing.sm) {
                                Text("Deep Search")
                                    .font(DS.Font.title)
                                    .foregroundStyle(DS.Colors.textPrimary)
                                Text("Search across notes, tasks, and projects — or ask AI to analyze your workspace")
                                    .font(DS.Font.body)
                                    .foregroundStyle(DS.Colors.textSecondary)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: 400)
                            }

                            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                                SearchSuggestion(text: "What did I work on this week?") { query = $0; performSearch() }
                                SearchSuggestion(text: "Summarize project progress") { query = $0; performSearch() }
                                SearchSuggestion(text: "Find tasks related to authentication") { query = $0; performSearch() }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, DS.Spacing.xxl)
                    }
                }
                .padding(DS.Spacing.xl)
            }
        }
        .onAppear { focused = true }
        .dsPage()
    }

    private func performSearch() {
        guard !query.isEmpty else { return }

        if searchMode == .workspace { return }

        isSearching = true
        let q = query
        let context = localResults.prefix(5).map { "\($0.type): \($0.title) — \($0.subtitle)" }.joined(separator: "\n")

        Task {
            do {
                let prompt = context.isEmpty
                    ? "Answer this question about my workspace: \(q)"
                    : "Based on this workspace data:\n\(context)\n\nAnswer: \(q)"
                let systemPrompt = "You are a knowledge assistant analyzing a user's workspace. Provide insights based on their notes, tasks, and projects. Be specific and actionable."

                let result = try await ClaudeService.shared.query(prompt, systemPrompt: systemPrompt)

                await MainActor.run {
                    aiResult = result
                    isSearching = false
                }
            } catch {
                await MainActor.run {
                    aiResult = "Error: \(error.localizedDescription)"
                    isSearching = false
                }
            }
        }
    }

    private func navigateTo(_ result: SearchResult) {
        switch result.type {
        case .note:
            appState.navigateToNote(result.id)
        case .task:
            appState.navigateToTask(result.id)
        case .project:
            appState.navigateToProject(result.id)
        case .context:
            appState.navigateToContext()
        }
    }

    private func extractSnippet(from text: String, matching query: String) -> String {
        let lower = text.lowercased()
        guard let range = lower.range(of: query) else { return String(text.prefix(100)) }
        let start = text.index(range.lowerBound, offsetBy: -40, limitedBy: text.startIndex) ?? text.startIndex
        let end = text.index(range.upperBound, offsetBy: 60, limitedBy: text.endIndex) ?? text.endIndex
        return "..." + text[start..<end].replacingOccurrences(of: "\n", with: " ") + "..."
    }
}

struct SearchResult: Identifiable {
    let id: UUID
    let type: ResultType
    let title: String
    let subtitle: String

    init(type: ResultType, title: String, subtitle: String, id: UUID) {
        self.type = type
        self.title = title
        self.subtitle = subtitle
        self.id = id
    }

    enum ResultType {
        case note, task, project, context

        var icon: String {
            switch self {
            case .note: "doc.text"
            case .task: "checklist"
            case .project: "folder"
            case .context: "tray.full"
            }
        }

        var color: Color {
            switch self {
            case .note: DS.Colors.info
            case .task: DS.Colors.success
            case .project: DS.Colors.teal
            case .context: DS.Colors.amber
            }
        }
    }
}

private struct SearchResultRow: View {
    let result: SearchResult
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: result.type.icon)
                    .font(.system(size: DS.IconSize.md))
                    .foregroundStyle(result.type.color)
                    .frame(width: 28, height: 28)
                    .background(result.type.color.opacity(0.08), in: RoundedRectangle(cornerRadius: DS.Radius.sm))

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(result.title)
                        .font(DS.Font.body)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    Text(result.subtitle)
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Colors.textSecondary)
                        .lineLimit(2)
                }

                Spacer()
            }
            .padding(DS.Spacing.md)
            .dsClickable()
        }
        .buttonStyle(.plainPointer)
    }
}

private struct SearchSuggestion: View {
    let text: String
    let action: (String) -> Void

    var body: some View {
        Button { action(text) } label: {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: DS.IconSize.sm + 1))
                    .foregroundStyle(DS.Colors.textTertiary)
                Text(text)
                    .font(DS.Font.caption)
                Spacer()
            }
            .padding(DS.Spacing.sm)
            .background(DS.Colors.fill, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
        }
        .buttonStyle(.plainPointer)
        .frame(maxWidth: 360)
    }
}
