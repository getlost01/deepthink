import Foundation

@Observable
final class KnowledgeExtractionService {
    static let shared = KnowledgeExtractionService()

    var isExtracting = false
    private var recentlyProcessedNotes: Set<UUID> = []
    private var activeTaggingEntries: Set<String> = []

    private init() {}

    // MARK: - Feature 6: Auto-extract from notes

    func extractFromNote(id: UUID, title: String, content: String) async {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              content.split(whereSeparator: \.isWhitespace).count >= 30,
              !recentlyProcessedNotes.contains(id) else { return }

        if recentlyProcessedNotes.count >= 500 { recentlyProcessedNotes.removeAll() }
        recentlyProcessedNotes.insert(id)

        await MainActor.run { isExtracting = true }
        defer { Task { @MainActor in isExtracting = false } }

        do {
            let prompt = """
            Extract key facts, concepts, and entities from this note. Output as a structured markdown document with:
            - A brief summary (2-3 sentences)
            - Key facts as bullet points
            - Named entities (people, tools, concepts) as a comma-separated list

            Note title: \(title)

            \(String(content.prefix(4000)))
            """

            let result = try await ClaudeService.shared.query(
                prompt,
                systemPrompt: "You extract structured knowledge from notes. Be concise. Output only the extraction, no preamble."
            )

            await MainActor.run {
                KnowledgeService.shared.createEntry(
                    title: "Extracted: \(title)",
                    content: result,
                    source: "manual",
                    tags: ["auto-extracted", "note"]
                )
            }
        } catch {
            StorageService.shared.writeLog("Knowledge extraction failed: \(error.localizedDescription)", to: "extraction")
        }
    }

    // MARK: - Feature 9: Auto-tagging

    func autoTag(entry: KnowledgeEntry) async -> [String] {
        guard !entry.content.isEmpty else { return entry.tags }

        do {
            let result = try await ClaudeService.shared.query(
                "Generate 3-5 short, specific tags for this content. Output only comma-separated tags, nothing else." +
                    "\n\nTitle: \(entry.title)\n\n\(String(entry.content.prefix(2000)))",
                systemPrompt: "Output only comma-separated lowercase tags. No explanations. No numbering."
            )

            return result
                .components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                .filter { !$0.isEmpty && $0.count < 30 }
        } catch {
            return entry.tags
        }
    }

    func autoTagAndUpdate(entry: KnowledgeEntry) async {
        guard !activeTaggingEntries.contains(entry.id) else { return }
        activeTaggingEntries.insert(entry.id)
        defer { activeTaggingEntries.remove(entry.id) }

        let tags = await autoTag(entry: entry)
        guard !tags.isEmpty else { return }

        updateEntryTags(entry: entry, tags: tags)
        await MainActor.run { KnowledgeService.shared.reload() }
    }

    private func updateEntryTags(entry: KnowledgeEntry, tags: [String]) {
        guard let data = FileManager.default.contents(atPath: entry.filePath.path),
              let text = String(data: data, encoding: .utf8) else { return }

        let (frontmatter, body) = KnowledgeService.shared.parseFrontmatter(text)
        var updated = frontmatter
        updated["tags"] = "[\(tags.map { "\"\($0)\"" }.joined(separator: ", "))]"

        let orderedKeys = ["title", "source", "bucket", "url", "tags", "imported_at"]
        var md = "---\n"
        for key in orderedKeys {
            if let value = updated[key] { md += "\(key): \(value)\n" }
        }
        for (key, value) in updated where !orderedKeys.contains(key) {
            md += "\(key): \(value)\n"
        }
        md += "---\n\n"
        md += body

        do {
            try md.write(to: entry.filePath, atomically: true, encoding: .utf8)
        } catch {
            KnowledgeService.shared.appState?.presentError(error, context: "Knowledge auto-tag")
        }
    }

    // MARK: - Feature 11: Conversation → Knowledge

    func extractFromConversation(messages: [AIMessage], title: String? = nil) async -> Bool {
        let conversationText = messages
            .filter { $0.role != .error }
            .map { "\($0.role == .user ? "User" : "Assistant"): \($0.content)" }
            .joined(separator: "\n\n")

        guard !conversationText.isEmpty else { return false }

        do {
            let result = try await ClaudeService.shared.query(
                """
                Extract knowledge from this conversation. Be concise but preserve all specifics —
                exact names, numbers, code, paths, commands, and error messages. No fluff, no paraphrasing technical terms.

                Capture:
                - Technical details (code, configs, commands, file paths)
                - Root causes and how things work
                - Decisions and their reasoning
                - Problems with solutions (the steps, not just the outcome)
                - Action items, data points, metrics

                Use short markdown headers by topic. Use code blocks for code/commands. Bullet points, not paragraphs.
                At the end, add a "## Related" section listing topic names or keywords from the conversation
                that connect to other areas (e.g. "Related: Proto project, knowledge stats bug, kanban board").
                This helps link entries without extra lookups.

                Conversation:
                \(String(conversationText.prefix(8000)))
                """,
                systemPrompt: "Extract knowledge from conversations as concise structured markdown. " +
                    "Keep every specific detail (names, numbers, code, paths) but cut filler words and redundancy. " +
                    "Dense and scannable, not verbose."
            )

            let entryTitle: String
            if let title {
                entryTitle = title
            } else {
                let raw = messages.first { $0.role == .user }?.content ?? "Conversation"
                let snippet: String
                if raw.count <= 60 {
                    snippet = raw
                } else {
                    let truncated = String(raw.prefix(60))
                    snippet = truncated.lastIndex(of: " ").map { String(truncated[..<$0]) } ?? truncated
                }
                entryTitle = "Chat: \(snippet) — \(Date().formatted(date: .abbreviated, time: .omitted))"
            }

            await MainActor.run {
                KnowledgeService.shared.createEntry(
                    title: String(entryTitle.prefix(100)),
                    content: result,
                    source: "manual",
                    tags: ["chat-extracted", "conversation"]
                )
            }
            return true
        } catch {
            StorageService.shared.writeLog("Chat extraction failed: \(error.localizedDescription)", to: "extraction")
            return false
        }
    }

    func clearProcessedNote(_ id: UUID) {
        recentlyProcessedNotes.remove(id)
    }
}
