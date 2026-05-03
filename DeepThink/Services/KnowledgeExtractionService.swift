import Foundation

@Observable
final class KnowledgeExtractionService {
    static let shared = KnowledgeExtractionService()

    var isExtracting = false
    private var recentlyProcessedNotes: Set<UUID> = []

    private init() {}

    // MARK: - Feature 6: Auto-extract from notes

    func extractFromNote(id: UUID, title: String, content: String) async {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              content.split(whereSeparator: \.isWhitespace).count >= 30,
              !recentlyProcessedNotes.contains(id) else { return }

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

            KnowledgeService.shared.createEntry(
                title: "Extracted: \(title)",
                content: result,
                source: "manual",
                tags: ["auto-extracted", "note"]
            )
        } catch {
            StorageService.shared.writeLog("Knowledge extraction failed: \(error.localizedDescription)", to: "extraction")
        }
    }

    // MARK: - Feature 9: Auto-tagging

    func autoTag(entry: KnowledgeEntry) async -> [String] {
        guard !entry.content.isEmpty else { return entry.tags }

        do {
            let result = try await ClaudeService.shared.query(
                "Generate 3-5 short, specific tags for this content. Output only comma-separated tags, nothing else.\n\nTitle: \(entry.title)\n\n\(String(entry.content.prefix(2000)))",
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
        let tags = await autoTag(entry: entry)
        guard !tags.isEmpty else { return }

        updateEntryTags(entry: entry, tags: tags)
        KnowledgeService.shared.reload()
    }

    private func updateEntryTags(entry: KnowledgeEntry, tags: [String]) {
        guard let data = FileManager.default.contents(atPath: entry.filePath.path),
              let text = String(data: data, encoding: .utf8) else { return }

        let (frontmatter, body) = KnowledgeService.shared.parseFrontmatter(text)
        var updated = frontmatter
        updated["tags"] = "[\(tags.joined(separator: ", "))]"

        var md = "---\n"
        for (key, value) in updated {
            md += "\(key): \(value)\n"
        }
        md += "---\n\n"
        md += body

        try? md.write(to: entry.filePath, atomically: true, encoding: .utf8)
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
                "Extract the most useful knowledge from this conversation. Include:\n- Key decisions or conclusions\n- Factual answers given\n- Solutions to problems discussed\n- Action items mentioned\n\nConversation:\n\(String(conversationText.prefix(6000)))",
                systemPrompt: "You extract reusable knowledge from conversations. Output structured markdown. Be concise. Only include information worth saving for future reference."
            )

            let entryTitle = title ?? "Chat: \(messages.first { $0.role == .user }?.content.prefix(50) ?? "Conversation") — \(Date().formatted(date: .abbreviated, time: .shortened))"

            KnowledgeService.shared.createEntry(
                title: String(entryTitle.prefix(100)),
                content: result,
                source: "manual",
                tags: ["chat-extracted", "conversation"]
            )
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
