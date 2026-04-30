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
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "sparkle.magnifyingglass")
                        .font(.title3)
                        .foregroundStyle(.orange)

                    TextField("Search your knowledge base...", text: $query)
                        .textFieldStyle(.plain)
                        .font(.title3)
                        .focused($focused)
                        .onSubmit { performSearch() }

                    if isSearching {
                        ProgressView().scaleEffect(0.7)
                    }

                    Button(action: performSearch) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.title3)
                            .foregroundStyle(query.isEmpty ? Color.secondary.opacity(0.3) : .orange)
                    }
                    .buttonStyle(.plain)
                    .disabled(query.isEmpty)
                }
                .padding(16)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.quaternary))

                Picker("Mode", selection: $searchMode) {
                    ForEach(SearchMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 360)
            }
            .padding(24)
            .background(.bar)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let aiResult, !aiResult.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: "brain.head.profile")
                                    .foregroundStyle(.purple)
                                Text("AI Analysis")
                                    .font(.headline)
                                Spacer()
                                Button {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(aiResult, forType: .string)
                                } label: {
                                    Image(systemName: "doc.on.doc")
                                        .font(.caption)
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
                        .padding(16)
                        .background(.background, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.purple.opacity(0.2)))
                    }

                    if !localResults.isEmpty {
                        Text("Workspace Results (\(localResults.count))")
                            .font(.headline)

                        ForEach(localResults) { result in
                            SearchResultRow(result: result) {
                                navigateTo(result)
                            }
                        }
                    }

                    if query.isEmpty && aiResult == nil {
                        VStack(spacing: 12) {
                            Image(systemName: "sparkle.magnifyingglass")
                                .font(.system(size: 40))
                                .foregroundStyle(.tertiary)
                            Text("Deep Search")
                                .font(.title3)
                                .fontWeight(.semibold)
                            Text("Search across notes, tasks, projects — or use AI to analyze and find answers")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 400)

                            VStack(alignment: .leading, spacing: 6) {
                                SearchSuggestion(text: "What did I work on this week?") { query = $0; performSearch() }
                                SearchSuggestion(text: "Summarize project progress") { query = $0; performSearch() }
                                SearchSuggestion(text: "Find tasks related to authentication") { query = $0; performSearch() }
                                SearchSuggestion(text: "What decisions were made recently?") { query = $0; performSearch() }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                    }
                }
                .padding(24)
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
            HStack(spacing: 12) {
                Image(systemName: result.type.icon)
                    .font(.body)
                    .foregroundStyle(result.type.color)
                    .frame(width: 28, height: 28)
                    .background(result.type.color.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))

                VStack(alignment: .leading, spacing: 2) {
                    Text(result.title).font(.callout).fontWeight(.medium).lineLimit(1)
                    Text(result.subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(10)
            .background(.background, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.quaternary.opacity(0.5)))
        }
        .buttonStyle(.plain)
    }
}

private struct SearchSuggestion: View {
    let text: String
    let action: (String) -> Void

    var body: some View {
        Button { action(text) } label: {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").font(.caption2).foregroundStyle(.orange)
                Text(text).font(.caption)
                Spacer()
            }
            .padding(8)
            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: 400)
    }
}
