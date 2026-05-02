import Foundation

@Observable
final class AgentFileService {
    static let shared = AgentFileService()

    var agents: [AgentFile] = []

    private let fm = FileManager.default
    private var agentsDir: URL { StorageService.shared.configsURL.appendingPathComponent("agents") }

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

    func buildSystemPrompt(for agent: AgentFile) -> String {
        var prompt = agent.systemPrompt

        let matchedRules = RuleFileService.shared.rulesAsSystemPrompt(for: ["agent": agent.name])
        if let rules = matchedRules {
            prompt += "\n\n# Active Rules\n\n" + rules
        }

        if !agent.knowledgeScope.isEmpty {
            let knowledge = KnowledgeService.shared.entries.filter { entry in
                agent.knowledgeScope.contains { scope in
                    entry.source.contains(scope) || entry.tags.contains(scope) || entry.title.lowercased().contains(scope.lowercased())
                }
            }
            if !knowledge.isEmpty {
                prompt += "\n\n# Knowledge Context\n\n"
                for entry in knowledge.prefix(10) {
                    prompt += "## \(entry.title)\n\(String(entry.content.prefix(500)))\n\n"
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
            ("Researcher", "Deep-dives into knowledge, synthesizes findings", "magnifyingglass.circle", nil,
             """
             You are a research agent for the DeepThink workspace. Your job is to:
             1. Analyze the knowledge base thoroughly before answering
             2. Cross-reference multiple sources when possible
             3. Cite which knowledge entries informed your answer
             4. Flag gaps — tell the user what data you're missing
             5. Provide structured findings with clear sections

             Be thorough but concise. Use bullet points for findings. Always indicate confidence level.
             """,
             ["web", "manual"]),
            ("Code Reviewer", "Reviews code with project context", "chevron.left.forwardslash.chevron.right", nil,
             """
             You are a senior code reviewer. When reviewing code:
             1. Check for security vulnerabilities (injection, XSS, auth issues)
             2. Identify performance bottlenecks
             3. Suggest simplifications and cleaner patterns
             4. Note missing error handling and edge cases
             5. Verify naming conventions and code style consistency

             Be direct. Use severity levels: 🔴 Critical, 🟡 Warning, 🔵 Suggestion.
             Format as a code review with line references when possible.
             """,
             ["code", "development"]),
            ("Task Planner", "Breaks work into tasks, estimates, prioritizes", "list.bullet.rectangle", nil,
             """
             You are a task planning agent. When the user describes work:
             1. Break it into concrete, actionable subtasks
             2. Estimate effort for each (S/M/L/XL)
             3. Identify dependencies between tasks
             4. Suggest priority order
             5. Flag risks and blockers

             Use the workspace context to understand existing tasks and avoid duplicates.
             Output structured markdown with checkboxes for each task.
             """,
             []),
            ("Writer", "Drafts, edits, and summarizes content", "pencil.circle", nil,
             """
             You are a writing assistant. Adapt to the user's needs:
             - **Drafting**: Write clear, well-structured content. Ask about audience and tone if unclear.
             - **Editing**: Improve clarity, fix grammar, tighten language. Show changes.
             - **Summarizing**: Extract key points. Use bullet points. Keep it concise.

             Default style: professional, concise, active voice. Avoid jargon unless the context is technical.
             When editing, explain WHY you made each significant change.
             """,
             ["writing"]),
            ("Analyst", "Analyzes data, output, and patterns", "chart.bar.xaxis", "claude-sonnet-4-6",
             """
             You are a data analysis agent. When given data or output:
             1. Identify key patterns, trends, and anomalies
             2. Provide quantitative summaries where possible
             3. Create structured analysis with clear sections
             4. Suggest actionable next steps
             5. Highlight anything concerning or unexpected

             Use tables for comparisons. Use bullet points for findings.
             Be precise with numbers. Always state your assumptions.
             """,
             ["analytics", "script"]),
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
