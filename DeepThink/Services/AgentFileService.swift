import Foundation

@Observable
final class AgentFileService {
    static let shared = AgentFileService()

    var agents: [AgentFile] = []

    private let fm = FileManager.default
    private var agentsDir: URL { StorageService.shared.agentsURL }

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

    func buildSystemPrompt(for agent: AgentFile, query: String? = nil) -> String {
        var prompt = agent.systemPrompt

        let matchedRules = RuleFileService.shared.rulesAsSystemPrompt(for: ["agent": agent.name])
        if let rules = matchedRules {
            prompt += "\n\n# Active Rules\n\n" + rules
        }

        if !agent.skills.isEmpty {
            let skillLines = agent.skills.compactMap { skillName -> String? in
                guard let skill = SkillFileService.shared.skills.first(where: {
                    $0.name == skillName || $0.commandName == skillName
                }) else { return nil }
                let desc = skill.systemPrompt.isEmpty ? skill.promptTemplate.prefix(60) : skill.systemPrompt.prefix(60)
                return "- /\(skill.commandName): \(desc)"
            }
            if !skillLines.isEmpty {
                prompt += "\n\n# Available Skills\nYou have the following skills available. When a user request matches a skill, suggest using it with /command-name:\n"
                prompt += skillLines.joined(separator: "\n")
            }
        }

        if !agent.knowledgeScope.isEmpty {
            if let query = query {
                // Smart retrieval: use query + agent scope for targeted context
                if let ctx = KnowledgeService.shared.ragContext(
                    for: query, maxTokens: 2000, agentScope: agent.knowledgeScope
                ) {
                    prompt += "\n\n" + ctx
                }
            } else {
                // Fallback: scope-filtered entries
                let knowledge = KnowledgeService.shared.entries.filter { entry in
                    agent.knowledgeScope.contains { scope in
                        entry.source.contains(scope) || entry.tags.contains(scope) || entry.title.lowercased().contains(scope.lowercased())
                    }
                }
                if !knowledge.isEmpty {
                    prompt += "\n\n# Knowledge Context\n\n"
                    for entry in knowledge.prefix(5) {
                        prompt += "## \(entry.title)\n\(String(entry.content.prefix(400)))\n\n"
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
        let url = agentsDir.appendingPathComponent("\(slug).md")

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
        let existing = (try? fm.contentsOfDirectory(at: agentsDir, includingPropertiesForKeys: nil))?.count ?? 0
        guard existing == 0 else { reload(); return }

        let defaults: [(String, String, String, String?, String, [String])] = [
            ("Researcher", "Deep-dives into your knowledge base, connects ideas", "magnifyingglass.circle", nil,
             """
             You are a research agent for the DeepThink workspace. Your job is to:
             1. Search the knowledge base thoroughly before answering
             2. Cross-reference multiple entries — find connections the user might miss
             3. Cite which knowledge entries informed your answer
             4. Flag gaps — tell the user what's missing and suggest what to capture
             5. When asked to explore a topic, check existing knowledge first, then suggest new sources

             Be thorough but structured. Use headings for sections. Always indicate whether your answer comes from the knowledge base or general knowledge.
             """,
             ["web", "manual"]),
            ("Daily Briefing", "Summarizes your workspace: tasks, notes, deadlines", "sun.horizon", nil,
             """
             You are a daily briefing assistant. When activated:
             1. Review open tasks — highlight overdue and due-today items
             2. Summarize recently edited notes and new knowledge entries
             3. List upcoming deadlines and reminders
             4. Suggest 2-3 priorities for today based on urgency and context
             5. Flag anything that seems stale or forgotten

             Keep it concise — this should be scannable in under 60 seconds. Use bullet points and bold for key items.
             """,
             []),
            ("Knowledge Curator", "Captures, tags, and organizes information", "brain", nil,
             """
             You are a knowledge curation assistant. Help the user:
             1. When given raw text, URLs, or pasted content — extract the key information worth saving
             2. Suggest accurate tags and categorization
             3. Identify connections to existing knowledge entries
             4. Rewrite messy captures into clean, searchable notes
             5. Spot duplicate or overlapping entries and suggest merging

             Your goal is to keep the knowledge base clean, well-tagged, and interconnected. Prefer quality over quantity.
             """,
             []),
            ("Writer", "Drafts, edits, and polishes any kind of text", "pencil.circle", nil,
             """
             You are a writing assistant. Adapt to what's needed:
             - **Drafting**: Write clear, well-structured content. Ask about audience and tone if unclear.
             - **Editing**: Improve clarity, fix grammar, tighten language. Show tracked changes.
             - **Summarizing**: Extract key points. Use bullet points. Be concise.
             - **Expanding**: Take bullet points or rough notes and expand into full prose.

             Default style: professional, concise, active voice. When editing, explain WHY you made significant changes.
             """,
             ["writing"]),
            ("Task Triage", "Prioritize and organize incoming tasks", "tray.and.arrow.down", "claude-sonnet-4-6",
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
             ["tasks", "projects"]),
            ("Planner", "Break goals into ordered, concrete steps", "list.bullet.clipboard", "claude-sonnet-4-6",
             """
             You are a planning agent. Given a goal or project, you decompose it into an ordered execution plan with concrete steps.

             For each step, specify:
             - What to do (specific action, not vague)
             - Which workspace tool to use if applicable (workspace_create_task, workspace_create_note, etc.)
             - Dependencies on previous steps
             - Time estimate

             Check existing workspace tasks and projects before planning — avoid duplicating work already in progress.

             Output format:
             1. **Step title** (tool: `tool_name` | est: Xh | depends: #N)
                Details about what specifically to do.

             End with: total estimated time, critical path, and first thing to do right now.
             """,
             ["tasks", "projects", "knowledge"]),
            ("Standup", "Generate daily async standup from workspace state", "person.wave.2", "claude-haiku-4-5-20251001",
             """
             You are a standup assistant. Pull workspace state and generate a crisp daily standup.

             Format (always):
             **Yesterday:** (tasks completed in last 24h, grouped by project)
             **Today:** (In Progress + highest priority To Do items)
             **Blockers:** (Urgent tasks, anything explicitly flagged as blocked)

             Rules:
             - Under 150 words total
             - Group by project when >1 project active
             - If no completed tasks yesterday, say "No completions — carried over from previous day"
             - Bold project names
             - Never add preamble or closing remarks — output only the standup block
             """,
             ["tasks", "projects"]),
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

        reload()
    }
}
