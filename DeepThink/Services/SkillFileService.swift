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

        return SkillFile(
            name: name,
            trigger: fm["trigger"] ?? "manual",
            icon: fm["icon"] ?? "sparkles",
            model: fm["model"],
            category: fm["category"] ?? "General",
            systemPrompt: systemPrompt,
            promptTemplate: promptTemplate,
            filePath: url,
            isBuiltIn: fm["built_in"] == "true"
        )
    }

    // MARK: - Execute

    @MainActor
    func execute(skill: SkillFile, context: [String: String]) async -> String {
        isExecuting = true
        defer { isExecuting = false }

        let resolved = interpolate(skill.promptTemplate, with: context)
        let system = skill.systemPrompt.isEmpty ? nil : interpolate(skill.systemPrompt, with: context)

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

    // MARK: - CRUD

    func save(skill: SkillFile) {
        var md = "---\n"
        md += "name: \(skill.name)\n"
        md += "trigger: \(skill.trigger)\n"
        md += "icon: \(skill.icon)\n"
        if let model = skill.model { md += "model: \(model)\n" }
        md += "category: \(skill.category)\n"
        if skill.isBuiltIn { md += "built_in: true\n" }
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

        let defaults: [(String, String, String, String, String)] = [
            ("Summarize", "text.justify.leading", "Writing",
             "You are a concise summarizer. Output only bullet points, no preamble.",
             "Summarize the following in 2-3 bullet points:\n\n{{input}}"),
            ("Extract Action Items", "checklist", "Productivity",
             "You extract actionable tasks. Output only a markdown list.",
             "Extract all actionable tasks from this text:\n\n{{input}}"),
            ("Improve Writing", "pencil.and.outline", "Writing",
             "You are an expert editor. Improve text while preserving meaning.",
             "Improve this text for clarity and conciseness. Return only the improved version:\n\n{{input}}"),
            ("Explain Code", "chevron.left.forwardslash.chevron.right", "Development",
             "Explain code in plain language. Be concise. Mention key patterns and issues.",
             "Explain this code clearly:\n\n```\n{{input}}\n```"),
            ("Generate Tags", "tag", "Organization",
             "Output only comma-separated tags. No explanations.",
             "Suggest 3-5 short tags for this content:\n\n{{input}}"),
            ("Break Down Task", "list.bullet.indent", "Productivity",
             "Output only a numbered list of subtasks. Each should be specific and actionable.",
             "Break this task into 3-7 smaller subtasks:\n\n{{input}}"),
            ("Draft Response", "envelope", "Communication",
             "Draft a clear, professional response.",
             "Draft a professional response to this message:\n\n{{input}}"),
            ("Daily Standup", "sun.horizon", "Productivity",
             "Generate a brief standup report with Done, In Progress, and Blockers sections.",
             "Based on these recent items, generate a standup update:\n\n{{input}}"),
        ]

        for (name, icon, category, system, prompt) in defaults {
            let slug = name.lowercased().replacingOccurrences(of: " ", with: "-")
            let url = dir.appendingPathComponent("\(slug).md")

            var md = "---\nname: \(name)\ntrigger: manual\nicon: \(icon)\ncategory: \(category)\nbuilt_in: true\n---\n\n"
            md += system + "\n\n---\n\n" + prompt
            try? md.write(to: url, atomically: true, encoding: .utf8)
        }

        reload()
    }
}
