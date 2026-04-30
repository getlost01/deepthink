import SwiftUI
import SwiftData

struct DeepSearchView: View {
    @Environment(AppState.self) private var appState
    @Query private var notes: [Note]
    @Query private var tasks: [TaskItem]
    @Query private var projects: [Project]
    @Query(filter: #Predicate<MCPServer> { $0.isEnabled }) private var activeServers: [MCPServer]

    @State private var query = ""
    @State private var isSearching = false
    @State private var aiResult: String?
    @State private var searchMode: SearchMode = .workspace
    @FocusState private var focused: Bool

    enum SearchMode: String, CaseIterable {
        case workspace = "Workspace"
        case ai = "AI Search"
        case web = "Web (MCP)"
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
        return results
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: DS.Spacing.md) {
                HStack(spacing: DS.Spacing.md) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14))
                        .foregroundStyle(DS.Colors.textTertiary)

                    TextField("Search your knowledge base...", text: $query)
                        .textFieldStyle(.plain)
                        .font(.title3)
                        .focused($focused)
                        .onSubmit { performSearch() }

                    if isSearching {
                        ProgressView().scaleEffect(0.7)
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.md)
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: DS.Radius.md))

                Picker("Mode", selection: $searchMode) {
                    ForEach(SearchMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 320)
            }
            .padding(DS.Spacing.xl)
            .background(.bar)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let aiResult, !aiResult.isEmpty {
                        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                            HStack(spacing: DS.Spacing.sm) {
                                Text("AI Analysis")
                                    .font(DS.Font.heading)
                                Spacer()
                                Button {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(aiResult, forType: .string)
                                } label: {
                                    Image(systemName: "doc.on.doc")
                                        .font(DS.Font.caption)
                                        .foregroundStyle(DS.Colors.textTertiary)
                                }
                                .buttonStyle(.plain)
                            }

                            if let attributed = try? AttributedString(markdown: aiResult, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
                                Text(attributed)
                                    .font(.callout)
                                    .textSelection(.enabled)
                            } else {
                                Text(aiResult)
                                    .font(.callout)
                                    .textSelection(.enabled)
                            }
                        }
                        .padding(DS.Spacing.lg)
                        .background(.background, in: RoundedRectangle(cornerRadius: DS.Radius.lg))
                        .overlay(RoundedRectangle(cornerRadius: DS.Radius.lg).strokeBorder(DS.Colors.border))
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
                        VStack(spacing: DS.Spacing.lg) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 32))
                                .foregroundStyle(.quaternary)
                            Text("Deep Search")
                                .font(DS.Font.heading)
                                .foregroundStyle(DS.Colors.textSecondary)

                            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                                SearchSuggestion(text: "What did I work on this week?") { query = $0; performSearch() }
                                SearchSuggestion(text: "Summarize project progress") { query = $0; performSearch() }
                                SearchSuggestion(text: "Find tasks related to authentication") { query = $0; performSearch() }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, DS.Spacing.xxxl)
                    }
                }
                .padding(DS.Spacing.xl)
            }
        }
        .onAppear { focused = true }
    }

    private func performSearch() {
        guard !query.isEmpty else { return }

        if searchMode == .workspace { return }

        isSearching = true
        let q = query
        let context = localResults.prefix(5).map { "\($0.type): \($0.title) — \($0.subtitle)" }.joined(separator: "\n")

        Task {
            do {
                let prompt: String
                let systemPrompt: String

                if searchMode == .web {
                    prompt = "Search the web and answer: \(q)"
                    systemPrompt = "You have access to web search. Search and provide comprehensive answers with sources."
                } else {
                    prompt = context.isEmpty
                        ? "Answer this question about my workspace: \(q)"
                        : "Based on this workspace data:\n\(context)\n\nAnswer: \(q)"
                    systemPrompt = "You are a knowledge assistant analyzing a user's workspace. Provide insights based on their notes, tasks, and projects. Be specific and actionable."
                }

                let result: String
                if searchMode == .web && !activeServers.isEmpty {
                    result = try await MCPService.shared.queryWithMCP(prompt: prompt, servers: Array(activeServers), systemPrompt: systemPrompt)
                } else {
                    result = try await ClaudeService.shared.query(prompt, systemPrompt: systemPrompt)
                }

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
            appState.selectedSection = .notes
            appState.selectedNoteID = result.id
        case .task:
            appState.selectedSection = .tasks
            appState.selectedTaskID = result.id
        case .project:
            appState.selectedSection = .projects
            appState.selectedProjectID = result.id
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
        case note, task, project

        var icon: String {
            switch self {
            case .note: "doc.text"
            case .task: "checklist"
            case .project: "folder"
            }
        }

        var color: Color {
            switch self {
            case .note: .blue
            case .task: .green
            case .project: .teal
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
                    .font(DS.Font.body)
                    .foregroundStyle(result.type.color)
                    .frame(width: 28, height: 28)
                    .background(result.type.color.opacity(0.08), in: RoundedRectangle(cornerRadius: DS.Radius.sm))

                VStack(alignment: .leading, spacing: 2) {
                    Text(result.title).font(DS.Font.body).fontWeight(.medium).lineLimit(1)
                    Text(result.subtitle).font(DS.Font.caption).foregroundStyle(.secondary).lineLimit(2)
                }

                Spacer()
            }
            .padding(DS.Spacing.md)
            .background(.background, in: RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).strokeBorder(DS.Colors.border))
        }
        .buttonStyle(.plain)
    }
}

private struct SearchSuggestion: View {
    let text: String
    let action: (String) -> Void

    var body: some View {
        Button { action(text) } label: {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "magnifyingglass").font(.system(size: 10)).foregroundStyle(DS.Colors.textTertiary)
                Text(text).font(DS.Font.caption)
                Spacer()
            }
            .padding(DS.Spacing.sm)
            .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: DS.Radius.sm))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: 360)
    }
}
