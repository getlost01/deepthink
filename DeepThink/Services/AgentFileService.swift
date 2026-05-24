import Foundation

@Observable
final class AgentFileService {
    static let shared = AgentFileService()

    var agents: [AgentFile] = []

    private let fm = FileManager.default
    private var agentsDir: URL {
        StorageService.shared.agentsURL
    }

    private init() {}

    // MARK: - Load

    func reload() {
        try? fm.createDirectory(at: agentsDir, withIntermediateDirectories: true)
        guard let files = try? fm.contentsOfDirectory(at: agentsDir, includingPropertiesForKeys: nil) else {
            agents = []
            return
        }
        agents = files
            .filter { $0.pathExtension == "md" }
            .compactMap { parseAgent(at: $0) }
            .sorted { $0.name < $1.name }
    }

    private func parseAgent(at url: URL) -> AgentFile? {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }

        let (meta, body) = KnowledgeService.shared.parseFrontmatter(text)
        guard let name = meta["name"] else { return nil }

        let skillsList = (meta["skills"] ?? "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let scopeList = (meta["knowledge_scope"] ?? "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        return AgentFile(
            name: name,
            role: meta["role"] ?? "",
            icon: meta["icon"] ?? "person.circle",
            model: meta["model"],
            systemPrompt: body,
            skills: skillsList,
            knowledgeScope: scopeList,
            filePath: url,
            isBuiltIn: meta["built_in"] == "true"
        )
    }

    // MARK: - Build Context

    private static let systemPromptCharBudget = 16000

    func buildSystemPrompt(for agent: AgentFile, query: String? = nil, context: [String: String] = [:]) -> String {
        var prompt = agent.systemPrompt

        var ruleContext = context
        ruleContext["agent"] = agent.name
        let matchedRules = RuleFileService.shared.rulesAsSystemPrompt(for: ruleContext)
        if let rules = matchedRules {
            prompt += "\n\n# Active Rules\n\n" + rules
        }

        if !agent.skills.isEmpty {
            let skillLines = agent.skills.compactMap { skillName -> String? in
                guard let skill = SkillFileService.shared.skills.first(where: {
                    $0.name == skillName || $0.commandName == skillName
                }) else { return nil }
                let desc = skill.systemPrompt.isEmpty ? skill.promptTemplate.prefix(80) : skill.systemPrompt.prefix(80)
                return "- /\(skill.commandName): \(desc)"
            }
            if !skillLines.isEmpty {
                prompt += "\n\n# Available Skills\nYou have the following skills available. When a user request matches a skill, suggest using it with /command-name:\n"
                prompt += skillLines.joined(separator: "\n")
            }
        }

        if !agent.knowledgeScope.isEmpty {
            let remaining = Self.systemPromptCharBudget - prompt.count
            guard remaining > 500 else { return prompt }

            if let query {
                let knowledgeTokenBudget = min(2000, remaining / 4)
                if let ctx = KnowledgeService.shared.ragContext(
                    for: query, maxTokens: knowledgeTokenBudget, agentScope: agent.knowledgeScope
                ) {
                    prompt += "\n\n" + String(ctx.prefix(remaining - 100))
                }
            } else {
                let knowledge = KnowledgeService.shared.entries.filter { entry in
                    agent.knowledgeScope.contains { scope in
                        entry.source.contains(scope) || entry.tags.contains(scope) || entry.title.lowercased().contains(scope.lowercased())
                    }
                }
                if !knowledge.isEmpty {
                    prompt += "\n\n# Knowledge Context\n\n"
                    var budget = remaining - 100
                    for entry in knowledge.prefix(5) {
                        let snippet = "## \(entry.title)\n\(String(entry.content.prefix(min(400, budget))))\n\n"
                        guard budget > 0 else { break }
                        prompt += snippet
                        budget -= snippet.count
                    }
                }
            }
        }

        return prompt
    }

    // MARK: - CRUD

    func save(agent: AgentFile) {
        var md = "---\n"
        md += "name: \(agent.name)\n"
        md += "role: \(agent.role)\n"
        md += "icon: \(agent.icon)\n"
        if let model = agent.model { md += "model: \(model)\n" }
        if !agent.skills.isEmpty { md += "skills: [\(agent.skills.joined(separator: ", "))]\n" }
        if !agent.knowledgeScope.isEmpty { md += "knowledge_scope: [\(agent.knowledgeScope.joined(separator: ", "))]\n" }
        if agent.isBuiltIn { md += "built_in: true\n" }
        md += "---\n\n"
        md += agent.systemPrompt

        try? md.write(to: agent.filePath, atomically: true, encoding: .utf8)
        reload()
    }

    func create(name: String, role: String, icon: String, model: String?, systemPrompt: String, skills: [String] = [], knowledgeScope: [String] = []) {
        try? fm.createDirectory(at: agentsDir, withIntermediateDirectories: true)
        let slug = name.lowercased().replacingOccurrences(of: " ", with: "-").replacingOccurrences(of: "[^a-z0-9\\-]", with: "", options: .regularExpression)
        var url = agentsDir.appendingPathComponent("\(slug).md")
        var counter = 2
        while fm.fileExists(atPath: url.path) {
            url = agentsDir.appendingPathComponent("\(slug)-\(counter).md")
            counter += 1
        }

        let agent = AgentFile(
            name: name, role: role, icon: icon, model: model,
            systemPrompt: systemPrompt, skills: skills, knowledgeScope: knowledgeScope,
            filePath: url, isBuiltIn: false
        )
        save(agent: agent)
    }

    func delete(agent: AgentFile) {
        try? fm.removeItem(at: agent.filePath)
        agents.removeAll { $0.id == agent.id }
    }

    // MARK: - Defaults

    func installDefaultAgents() {
        try? fm.createDirectory(at: agentsDir, withIntermediateDirectories: true)

        let versionFile = agentsDir.appendingPathComponent(".version")
        let currentVersion = "2"
        if (try? String(contentsOf: versionFile, encoding: .utf8)) == currentVersion {
            reload(); return
        }

        if let files = try? fm.contentsOfDirectory(at: agentsDir, includingPropertiesForKeys: nil) {
            for file in files where file.pathExtension == "md" {
                if let text = try? String(contentsOf: file, encoding: .utf8), text.contains("built_in: true") {
                    try? fm.removeItem(at: file)
                }
            }
        }

        let defaults: [(String, String, String, String?, String, [String])] = [
            (
                "Researcher",
                "Deep-dives into your knowledge base, connects ideas",
                "magnifyingglass.circle",
                nil,
                """
                You are a research agent for the DeepThink workspace. Your job is to:
                1. Search the knowledge base thoroughly before answering
                2. Cross-reference multiple entries — find connections the user might miss
                3. Cite which knowledge entries informed your answer
                4. Flag gaps — tell the user what's missing and suggest what to capture
                5. When asked to explore a topic, check existing knowledge first, then suggest new sources

                Be thorough but structured. Use headings for sections. Always indicate whether your answer comes from the knowledge base or general knowledge.
                """,
                ["web", "manual"]
            ),
            (
                "Daily Briefing",
                "Summarizes your workspace: tasks, notes, deadlines",
                "sun.horizon",
                nil,
                """
                You are a daily briefing assistant. When activated:
                1. Review open tasks — highlight overdue and due-today items
                2. Summarize recently edited notes and new knowledge entries
                3. List upcoming deadlines and reminders
                4. Suggest 2-3 priorities for today based on urgency and context
                5. Flag anything that seems stale or forgotten

                Keep it concise — this should be scannable in under 60 seconds. Use bullet points and bold for key items.
                """,
                []
            ),
            (
                "Writer",
                "Drafts, edits, and polishes any kind of text",
                "pencil.circle",
                nil,
                """
                You are a writing assistant. Adapt to what's needed:
                - **Drafting**: Write clear, well-structured content. Ask about audience and tone if unclear.
                - **Editing**: Improve clarity, fix grammar, tighten language. Show tracked changes.
                - **Summarizing**: Extract key points. Use bullet points. Be concise.
                - **Expanding**: Take bullet points or rough notes and expand into full prose.

                Default style: professional, concise, active voice. When editing, explain WHY you made significant changes.
                """,
                ["writing"]
            ),
            (
                "Task Triage",
                "Prioritize and organize incoming tasks",
                "tray.and.arrow.down",
                "claude-sonnet-4-6",
                """
                You are a task triage agent for DeepThink. Given a brain dump, list, or description of work, you organize it into actionable tasks.

                Rules:
                - Tasks with deadlines <3 days → Urgent
                - Dependency blockers or things blocking others → High
                - Estimate story points: 1 (< 1h), 2 (half day), 3 (1 day), 5 (2-3 days), 8 (1 week)
                - Always assign a project — ask if unclear
                - Split any task that would be >5 story points

                Output a JSON array ready for workspace import:
                [{"title": "...", "priority": "High", "status": "To Do", "storyPoints": 2, "project": "...", "dueDate": "YYYY-MM-DD or null"}]

                After the JSON, add a brief plain-English summary of what you organized and any clarifying questions.
                """,
                ["tasks", "projects"]
            )
        ]

        for (name, role, icon, model, prompt, scope) in defaults {
            let slug = name.lowercased().replacingOccurrences(of: " ", with: "-")
            let url = agentsDir.appendingPathComponent("\(slug).md")

            var md = "---\nname: \(name)\nrole: \(role)\nicon: \(icon)\n"
            if let model { md += "model: \(model)\n" }
            if !scope.isEmpty { md += "knowledge_scope: [\(scope.joined(separator: ", "))]\n" }
            md += "built_in: true\n---\n\n" + prompt
            try? md.write(to: url, atomically: true, encoding: .utf8)
        }

        try? currentVersion.write(to: versionFile, atomically: true, encoding: .utf8)
        reload()
    }
}
