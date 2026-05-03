import SwiftUI
import SwiftData

struct WebResult: Identifiable {
    let id = UUID()
    let title: String
    let url: String
    let snippet: String
}

struct DeepSearchView: View {
    @Environment(AppState.self) private var appState
    @Query private var notes: [Note]
    @Query private var tasks: [TaskItem]
    @Query private var projects: [Project]

    @State private var query = ""
    @State private var isSearching = false
    @State private var aiResult: String?
    @State private var webResults: [WebResult] = []
    @State private var searchMode: SearchMode = .workspace
    @FocusState private var focused: Bool

    enum SearchMode: String, CaseIterable {
        case workspace = "Workspace"
        case ai = "AI Search"
        case web = "Web"
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
                }
                .dsInputField()

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

                    if !webResults.isEmpty {
                        Text("Web Results (\(webResults.count))")
                            .font(DS.Font.heading)

                        ForEach(webResults) { result in
                            WebResultRow(result: result)
                        }
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
    }

    private func performSearch() {
        guard !query.isEmpty else { return }

        if searchMode == .workspace { return }

        isSearching = true
        webResults = []
        let q = query
        let context = localResults.prefix(5).map { "\($0.type): \($0.title) — \($0.subtitle)" }.joined(separator: "\n")

        if searchMode == .web {
            Task {
                let parsed: [WebResult] = []

                await MainActor.run {
                    webResults = parsed
                }

                do {
                    let result: String
                    if !parsed.isEmpty {
                        let webContext = parsed.map { "[\($0.title)](\($0.url))\n\($0.snippet)" }.joined(separator: "\n\n")
                        let prompt = "Based on these web search results:\n\n\(webContext)\n\nAnswer the question: \(q)\n\nCite sources with their URLs where relevant."
                        let systemPrompt = "You are a research assistant. Synthesize the provided web search results into a clear, comprehensive answer. Include source URLs as markdown links."
                        result = try await ClaudeService.shared.query(prompt, systemPrompt: systemPrompt)
                    } else {
                        let prompt = "Answer the following question using your training knowledge: \(q)"
                        let systemPrompt = "You are a knowledgeable assistant. Answer the question thoroughly using your training data. Note that live web search was unavailable, so your answer is based on training knowledge up to your cutoff date."
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
            return
        }

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

    static func parseWebResults(_ output: String) -> [WebResult] {
        var results: [WebResult] = []
        let lines = output.components(separatedBy: "\n")
        var i = 0
        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { i += 1; continue }

            // Title line (not indented in original)
            let rawLine = lines[i]
            let isIndented = rawLine.hasPrefix("  ") || rawLine.hasPrefix("\t")

            if !isIndented && !line.isEmpty {
                let title = line
                var url = ""
                var snippet = ""

                // Next line: URL (indented)
                if i + 1 < lines.count {
                    let nextLine = lines[i + 1].trimmingCharacters(in: .whitespaces)
                    if nextLine.hasPrefix("http://") || nextLine.hasPrefix("https://") {
                        url = nextLine
                        i += 1
                    }
                }

                // Next line: Snippet (indented)
                if i + 1 < lines.count {
                    let snippetLine = lines[i + 1].trimmingCharacters(in: .whitespaces)
                    if !snippetLine.isEmpty && !snippetLine.hasPrefix("http://") && !snippetLine.hasPrefix("https://") {
                        snippet = snippetLine
                        i += 1
                    }
                }

                if !url.isEmpty || !snippet.isEmpty {
                    results.append(WebResult(title: title, url: url, snippet: snippet))
                }
            }
            i += 1
        }
        return results
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
            case .note: .blue
            case .task: .green
            case .project: .teal
            case .context: .orange
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

                VStack(alignment: .leading, spacing: 2) {
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

private struct WebResultRow: View {
    let result: WebResult

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "globe")
                    .font(.system(size: DS.IconSize.md))
                    .foregroundStyle(.blue)
                    .frame(width: 28, height: 28)
                    .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: DS.Radius.sm))

                VStack(alignment: .leading, spacing: 2) {
                    Text(result.title)
                        .font(DS.Font.body)
                        .fontWeight(.medium)
                        .lineLimit(1)

                    if !result.url.isEmpty, let url = URL(string: result.url) {
                        Link(destination: url) {
                            Text(result.url)
                                .font(DS.Font.small)
                                .foregroundStyle(DS.Colors.accent)
                                .lineLimit(1)
                        }
                    }
                }

                Spacer()
            }

            if !result.snippet.isEmpty {
                Text(result.snippet)
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Colors.textSecondary)
                    .lineLimit(3)
                    .padding(.leading, 28 + DS.Spacing.sm)
            }
        }
        .padding(DS.Spacing.md)
        .dsBordered()
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
