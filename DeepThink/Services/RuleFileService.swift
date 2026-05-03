import Foundation

@Observable
final class RuleFileService {
    static let shared = RuleFileService()

    var rules: [RuleFile] = []

    private let fm = FileManager.default

    private init() {}

    // MARK: - Load

    func reload() {
        let dir = StorageService.shared.rulesConfigURL
        guard let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else {
            rules = []
            return
        }
        rules = files
            .filter { $0.pathExtension == "md" }
            .compactMap { parseRule(at: $0) }
            .sorted { $0.category < $1.category }
    }

    private func parseRule(at url: URL) -> RuleFile? {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }

        let (fm, body) = KnowledgeService.shared.parseFrontmatter(text)
        guard let name = fm["name"] else { return nil }

        return RuleFile(
            name: name,
            trigger: fm["trigger"] ?? "always",
            icon: fm["icon"] ?? "bolt",
            category: fm["category"] ?? "General",
            instruction: body,
            filePath: url,
            isBuiltIn: fm["built_in"] == "true"
        )
    }

    // MARK: - Match

    func matchingRules(for context: [String: String]) -> [RuleFile] {
        rules.filter { rule in
            let trigger = rule.trigger
            if trigger == "always" { return true }
            for (key, value) in context {
                if key == trigger || key.hasPrefix(trigger + ".") || trigger.hasPrefix(key + ".") { return true }
                if trigger.contains(key) || trigger.contains(value) { return true }
            }
            return false
        }
    }

    func rulesAsSystemPrompt(for context: [String: String]) -> String? {
        let matched = matchingRules(for: context)
        guard !matched.isEmpty else { return nil }
        return matched.map { "## Rule: \($0.name)\n\($0.instruction)" }.joined(separator: "\n\n")
    }

    // MARK: - CRUD

    func save(rule: RuleFile) {
        var md = "---\n"
        md += "name: \(rule.name)\n"
        md += "trigger: \(rule.trigger)\n"
        md += "icon: \(rule.icon)\n"
        md += "category: \(rule.category)\n"
        if rule.isBuiltIn { md += "built_in: true\n" }
        md += "---\n\n"
        md += rule.instruction

        try? md.write(to: rule.filePath, atomically: true, encoding: .utf8)
        reload()
    }

    func create(name: String, trigger: String, icon: String, category: String, instruction: String) {
        let dir = StorageService.shared.rulesConfigURL
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)

        let slug = name.lowercased().replacingOccurrences(of: " ", with: "-").replacingOccurrences(of: "[^a-z0-9\\-]", with: "", options: .regularExpression)
        let url = dir.appendingPathComponent("\(slug).md")

        let rule = RuleFile(name: name, trigger: trigger, icon: icon, category: category, instruction: instruction, filePath: url, isBuiltIn: false)
        save(rule: rule)
    }

    func delete(rule: RuleFile) {
        try? fm.removeItem(at: rule.filePath)
        rules.removeAll { $0.id == rule.id }
    }

    // MARK: - Defaults

    func installDefaultRules() {
        let dir = StorageService.shared.rulesConfigURL
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)

        let existing = (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil))?.count ?? 0
        guard existing == 0 else { reload(); return }

        let defaults: [(String, String, String, String, String)] = [
            ("Meeting Notes", "note.tagged.meeting", "person.3", "Productivity",
             "When working with meeting notes, always:\n1. Extract action items as a bullet list\n2. Identify owners for each action\n3. Note key decisions made\n4. Flag unresolved questions"),
            ("Code Review", "note.tagged.code", "chevron.left.forwardslash.chevron.right", "Development",
             "When reviewing code:\n1. Check for security vulnerabilities\n2. Identify performance issues\n3. Suggest simplifications\n4. Note missing error handling"),
            ("Task Breakdown", "task.created", "list.bullet.indent", "Productivity",
             "When a new complex task is created, suggest breaking it into 3-5 subtasks. Each subtask should be specific, actionable, and estimable."),
            ("Writing Style", "always", "textformat", "Writing",
             "When helping with writing:\n- Be concise and direct\n- Use active voice\n- Avoid jargon unless the context is technical\n- Prefer short sentences"),
        ]

        for (name, trigger, icon, category, instruction) in defaults {
            let slug = name.lowercased().replacingOccurrences(of: " ", with: "-")
            let url = dir.appendingPathComponent("\(slug).md")

            var md = "---\nname: \(name)\ntrigger: \(trigger)\nicon: \(icon)\ncategory: \(category)\nbuilt_in: true\n---\n\n"
            md += instruction
            try? md.write(to: url, atomically: true, encoding: .utf8)
        }

        reload()
    }
}
