import Foundation

@Observable
final class SkillFileService {
    static let shared = SkillFileService()

    var skills: [SkillFile] = []
    var isExecuting = false
    var lastResult: String?

    private let fm = FileManager.default

    private init() {}

    // MARK: - Load

    func reload() {
        let dir = StorageService.shared.skillsConfigURL
        guard let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else {
            skills = []
            return
        }
        skills = files
            .filter { $0.pathExtension == "md" }
            .compactMap { parseSkill(at: $0) }
            .sorted { $0.category < $1.category }
    }

    private func parseSkill(at url: URL) -> SkillFile? {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }

        let (fm, body) = KnowledgeService.shared.parseFrontmatter(text)
        guard let name = fm["name"] else { return nil }

        let parts = body.components(separatedBy: "\n---\n")
        let systemPrompt = parts.count > 1 ? parts[0].trimmingCharacters(in: .whitespacesAndNewlines) : ""
        let promptTemplate = parts.count > 1 ? parts[1...].joined(separator: "\n---\n").trimmingCharacters(in: .whitespacesAndNewlines) : body

        let scopeList = (fm["knowledge_scope"] ?? "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        return SkillFile(
            name: name,
            trigger: fm["trigger"] ?? "manual",
            icon: fm["icon"] ?? "sparkles",
            model: fm["model"],
            category: fm["category"] ?? "General",
            systemPrompt: systemPrompt,
            promptTemplate: promptTemplate,
            filePath: url,
            isBuiltIn: fm["built_in"] == "true",
            isPinned: fm["pinned"] == "true",
            knowledgeScope: scopeList,
            command: fm["command"] ?? ""
        )
    }

    // MARK: - Lookup

    func skill(forCommand command: String) -> SkillFile? {
        skills.first { $0.commandName == command }
    }

    var pinnedSkills: [SkillFile] {
        skills.filter(\.isPinned)
    }

    func togglePin(skill: SkillFile) {
        guard let idx = skills.firstIndex(where: { $0.id == skill.id }) else { return }
        skills[idx].isPinned.toggle()
        save(skill: skills[idx])
    }

    // MARK: - Execute

    @MainActor
    func execute(skill: SkillFile, context: [String: String]) async -> String {
        isExecuting = true
        defer { isExecuting = false }

        let resolved = resolveRefs(in: interpolate(skill.promptTemplate, with: context), context: context)
        var system = skill.systemPrompt.isEmpty ? nil : resolveRefs(in: interpolate(skill.systemPrompt, with: context), context: context)

        // Auto-inject relevant knowledge context into skill execution
        let input = context["input"] ?? resolved
        let scopeParam: [String]? = skill.knowledgeScope.isEmpty ? nil : skill.knowledgeScope
        if let ragContext = KnowledgeService.shared.ragContext(for: input, maxTokens: 1500, agentScope: scopeParam) {
            let base = system ?? "You are a helpful assistant."
            system = base + "\n\n" + ragContext
        }

        do {
            let result = try await ClaudeService.shared.query(resolved, systemPrompt: system)
            lastResult = result
            return result
        } catch {
            lastResult = "Error: \(error.localizedDescription)"
            return lastResult!
        }
    }

    // MARK: - Interpolation

    func interpolate(_ template: String, with context: [String: String]) -> String {
        var result = template
        let pattern = #"\{\{([^}]+)\}\}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return template }

        let matches = regex.matches(in: template, range: NSRange(template.startIndex..., in: template))
        for match in matches.reversed() {
            guard let range = Range(match.range, in: template),
                  let keyRange = Range(match.range(at: 1), in: template) else { continue }
            let key = String(template[keyRange]).trimmingCharacters(in: .whitespaces)
            let value = context[key] ?? ""
            result = result.replacingCharacters(in: range, with: value)
        }
        return result
    }

    private func levenshtein(_ a: String, _ b: String) -> Int {
        let a = Array(a), b = Array(b)
        guard !a.isEmpty, !b.isEmpty else { return max(a.count, b.count) }
        var dp = Array(0...b.count)
        for i in 1...a.count {
            var prev = dp[0]
            dp[0] = i
            for j in 1...b.count {
                let temp = dp[j]
                dp[j] = a[i - 1] == b[j - 1] ? prev : 1 + min(prev, min(dp[j], dp[j - 1]))
                prev = temp
            }
        }
        return dp[b.count]
    }

    private func resolveRefs(in template: String, context: [String: String]) -> String {
        guard let regex = try? NSRegularExpression(
            pattern: #"@(note|task|reminder):([^\n@]+)"#,
            options: .caseInsensitive
        ) else { return template }

        let nsTemplate = template as NSString
        let matches = regex.matches(in: template, range: NSRange(location: 0, length: nsTemplate.length))
        guard !matches.isEmpty else { return template }

        var result = template
        for match in matches.reversed() {
            guard let fullRange = Range(match.range, in: template),
                  let typeRange = Range(match.range(at: 1), in: template),
                  let titleRange = Range(match.range(at: 2), in: template) else { continue }

            let refType = String(template[typeRange]).lowercased()
            let refTitle = String(template[titleRange]).trimmingCharacters(in: .whitespaces)

            let replacement: String
            let indexKey = "\(refType)s_index"

            if let jsonString = context[indexKey],
               let data = jsonString.data(using: .utf8),
               let array = try? JSONSerialization.jsonObject(with: data) as? [[String: String]] {
                let exact = array.first { ($0["title"] ?? "").lowercased() == refTitle.lowercased() }
                let found: [String: String]?
                if let e = exact {
                    found = e
                } else {
                    let candidate = array.min { a, b in
                        levenshtein((a["title"] ?? "").lowercased(), refTitle.lowercased()) <
                            levenshtein((b["title"] ?? "").lowercased(), refTitle.lowercased())
                    }
                    let threshold = max(1, refTitle.count / 5)
                    if let c = candidate, levenshtein((c["title"] ?? "").lowercased(), refTitle.lowercased()) <= threshold {
                        found = c
                    } else {
                        found = nil
                    }
                }
                let isFuzzy = exact == nil && found != nil
                if let entry = found {
                    let actualTitle = entry["title"] ?? refTitle
                    let labelSuffix = isFuzzy ? " (matched \"\(refTitle)\")" : ""
                    switch refType {
                    case "note":
                        let content = entry["content"] ?? ""
                        replacement = "[Note: \"\(actualTitle)\"\(labelSuffix)]\n\(content)"
                    case "task":
                        let status = entry["status"] ?? ""
                        let detail = entry["detail"] ?? ""
                        replacement = "[Task: \"\(actualTitle)\"\(labelSuffix) (\(status))]\n\(detail)"
                    case "reminder":
                        let notes = entry["notes"] ?? ""
                        replacement = "[Reminder: \"\(actualTitle)\"\(labelSuffix)]\n\(notes)"
                    default:
                        replacement = "[Ref: \"\(refTitle)\"]"
                    }
                } else {
                    replacement = "@\(refType):\(refTitle) [not found]"
                }
            } else {
                replacement = "@\(refType):\(refTitle) [not found]"
            }

            result = result.replacingCharacters(in: fullRange, with: replacement)
        }
        return result
    }

    // MARK: - CRUD

    func save(skill: SkillFile) {
        var md = "---\n"
        md += "name: \(skill.name)\n"
        md += "trigger: \(skill.trigger)\n"
        md += "icon: \(skill.icon)\n"
        if let model = skill.model { md += "model: \(model)\n" }
        md += "category: \(skill.category)\n"
        if !skill.knowledgeScope.isEmpty { md += "knowledge_scope: [\(skill.knowledgeScope.joined(separator: ", "))]\n" }
        if skill.isBuiltIn { md += "built_in: true\n" }
        if skill.isPinned { md += "pinned: true\n" }
        if !skill.command.isEmpty { md += "command: \(skill.command)\n" }
        md += "---\n\n"
        if !skill.systemPrompt.isEmpty {
            md += skill.systemPrompt + "\n\n---\n\n"
        }
        md += skill.promptTemplate

        try? md.write(to: skill.filePath, atomically: true, encoding: .utf8)
        reload()
    }

    func create(name: String, category: String, icon: String, systemPrompt: String, promptTemplate: String, trigger: String = "manual", model: String? = nil) {
        let dir = StorageService.shared.skillsConfigURL
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)

        let slug = name.lowercased().replacingOccurrences(of: " ", with: "-").replacingOccurrences(of: "[^a-z0-9\\-]", with: "", options: .regularExpression)
        let url = dir.appendingPathComponent("\(slug).md")

        let skill = SkillFile(
            name: name, trigger: trigger, icon: icon, model: model,
            category: category, systemPrompt: systemPrompt, promptTemplate: promptTemplate,
            filePath: url, isBuiltIn: false
        )
        save(skill: skill)
    }

    func delete(skill: SkillFile) {
        try? fm.removeItem(at: skill.filePath)
        skills.removeAll { $0.id == skill.id }
    }

    // MARK: - Default Skills

    func installDefaultSkills() {
        let dir = StorageService.shared.skillsConfigURL
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)

        let existing = (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil))?.count ?? 0
        guard existing == 0 else { reload(); return }

        let defaults: [(String, String, String, String, String, [String])] = [
            (
                "Summarize",
                "text.justify.leading",
                "Writing",
                "You are a concise summarizer. Output only bullet points, no preamble.",
                "Summarize the following in 3-5 bullet points. Lead each bullet with the key takeaway:\n\n{{input}}",
                []
            ),
            (
                "Extract Action Items",
                "checklist",
                "Productivity",
                "You extract actionable tasks. Output only a markdown checklist. Each item should be specific enough to act on immediately.",
                "Extract all actionable tasks from this text. Format as a markdown checklist with - [ ] prefix:\n\n{{input}}",
                []
            ),
            (
                "Clean Up Note",
                "doc.text",
                "Knowledge",
                "You rewrite messy captures into clean, well-structured notes. Preserve all facts. Add a clear title if missing. Use markdown headings and bullet points.",
                "Clean up and restructure this note. Keep all information but make it scannable and well-organized:\n\n{{input}}",
                []
            ),
            (
                "Auto-Tag",
                "tag",
                "Knowledge",
                "Output only comma-separated tags. No explanations. Tags should be lowercase, specific, and useful for later retrieval.",
                "Suggest 3-6 specific tags for this content. Output only the tags, comma-separated:\n\n{{input}}",
                []
            ),
            (
                "Connect Ideas",
                "link",
                "Knowledge",
                "You find connections between ideas. Identify themes, contradictions, complementary concepts, and potential synthesis points.",
                "Analyze these pieces of information and identify connections, patterns, or contradictions between them:\n\n{{input}}",
                []
            ),
            (
                "Weekly Review",
                "calendar",
                "Productivity",
                "Generate a structured weekly review. Sections: Accomplished, In Progress, Blocked, Next Week Priorities. Be concise.",
                "Based on these items from the past week, generate a weekly review:\n\n{{input}}",
                []
            ),
            (
                "Daily Standup",
                "sun.max",
                "Productivity",
                "",
                """
                You summarize yesterday's completed work and today's planned work from the workspace. \
                Be concise, bullet-pointed, Slack-ready. Group by project. Keep total under 150 words.

                Generate my standup for today. Show:
                - **Yesterday:** tasks moved to Done in the last 24h
                - **Today:** tasks In Progress or To Do, ordered by priority
                - **Blockers:** anything Urgent or explicitly blocked

                Group by project if more than one is active. No preamble, output only the standup.
                """,
                ["tasks", "projects"]
            ),
            (
                "Project Health Check",
                "chart.bar.doc.horizontal",
                "Projects",
                "",
                """
                You analyze a project's task distribution, overdue items, and stalled work. \
                Surface risks and blockers clearly. Be direct — no filler.

                Analyze project "{{input}}" and report:
                1. Task breakdown by status (counts + %)
                2. Overdue tasks (past due date, not Done/Cancelled)
                3. Tasks stuck In Progress >7 days
                4. Tasks with no due date and High/Urgent priority
                5. Top 3 risks based on the above

                Format as sections with bullet points.
                """,
                ["tasks", "projects", "notes"]
            ),
            (
                "Find Knowledge Gaps",
                "questionmark.diamond",
                "Knowledge",
                "",
                """
                You identify topics mentioned in tasks and notes that lack corresponding knowledge base entries. \
                Surface what's undocumented.

                Scan my current tasks and notes. Identify topics, decisions, concepts, or tools \
                that are referenced but NOT documented in the knowledge base.

                Output as a ranked list:
                - **Topic** — why it matters, which task/note references it
                - Sort by: how frequently referenced > how recently mentioned

                End with 3 specific capture prompts the user can act on immediately.
                """,
                ["tasks", "notes", "knowledge"]
            )
        ]

        for (name, icon, category, system, prompt, scope) in defaults {
            let slug = name.lowercased().replacingOccurrences(of: " ", with: "-")
            let url = dir.appendingPathComponent("\(slug).md")

            var md = "---\nname: \(name)\ntrigger: manual\nicon: \(icon)\ncategory: \(category)\n"
            if !scope.isEmpty { md += "knowledge_scope: [\(scope.joined(separator: ", "))]\n" }
            md += "built_in: true\n---\n\n"
            if system.isEmpty {
                md += prompt
            } else {
                md += system + "\n\n---\n\n" + prompt
            }
            try? md.write(to: url, atomically: true, encoding: .utf8)
        }

        reload()
    }
}
