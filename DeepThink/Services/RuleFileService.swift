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

        let priority = Int(fm["priority"] ?? "0") ?? 0
        let isDisabled = fm["disabled"] == "true"

        return RuleFile(
            name: name,
            trigger: fm["trigger"] ?? "always",
            icon: fm["icon"] ?? "bolt",
            category: fm["category"] ?? "General",
            instruction: body,
            filePath: url,
            isBuiltIn: fm["built_in"] == "true",
            priority: priority,
            isDisabled: isDisabled
        )
    }

    // MARK: - Match

    func matchingRules(for context: [String: String]) -> [RuleFile] {
        rules.filter { rule in
            guard !rule.isDisabled else { return false }
            let trigger = rule.trigger
            if trigger == "always" { return true }

            // Structured trigger matching
            if trigger.hasPrefix("event:") {
                let eventName = String(trigger.dropFirst(6))
                return context.keys.contains(eventName)
            }
            if trigger.hasPrefix("tag:") {
                let tagName = String(trigger.dropFirst(4))
                return context.keys.contains("note.tagged.\(tagName)")
            }
            if trigger.hasPrefix("agent:") {
                let agentName = String(trigger.dropFirst(6))
                return context["agent"] == agentName
            }
            if trigger.hasPrefix("content:") {
                let contentType = String(trigger.dropFirst(8))
                return context["content_type"] == contentType
            }
            if trigger.hasPrefix("section:") {
                let sectionName = String(trigger.dropFirst(8))
                return context["section"] == sectionName
            }

            // Backward compatibility: exact key match (not substring)
            return context.keys.contains(trigger)
        }
        .sorted { $0.priority > $1.priority }
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
        if rule.priority != 0 { md += "priority: \(rule.priority)\n" }
        if rule.isDisabled { md += "disabled: true\n" }
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
            (
                "Knowledge Quality",
                "always",
                "checkmark.shield",
                "Knowledge",
                """
                When saving or editing knowledge entries:
                - Ensure the title is descriptive and searchable
                - Suggest tags if none exist
                - Flag if content is too vague to be useful later
                - Prefer structured formats (headings, bullets) over walls of text
                """
            ),
            (
                "Meeting Notes",
                "tag:meeting",
                "person.2",
                "Productivity",
                """
                When working with meeting notes:
                1. Extract action items as a checklist with owners
                2. Highlight key decisions in bold
                3. Note unresolved questions separately
                4. Add a one-line summary at the top
                """
            ),
            (
                "Source Attribution",
                "content:web",
                "globe",
                "Knowledge",
                """
                When capturing content from external sources:
                - Always include the source URL
                - Note the date of capture
                - Distinguish between direct quotes and paraphrased content
                - Flag if the source may become outdated quickly
                """
            ),
            (
                "Date-Stamp Decisions",
                "always",
                "calendar.badge.clock",
                "Knowledge Quality",
                """
                When capturing any decision, assumption, or conclusion — always include the date it was made.
                Format: "(decided YYYY-MM-DD)" appended inline.
                Apply to: knowledge entries, notes about architecture/design/process, any "we decided to..." statement.
                This prevents stale decisions from being treated as current guidance.
                """
            ),
            (
                "Tasks Require Project",
                "always",
                "folder.badge.plus",
                "Workspace Hygiene",
                """
                Every new task must be assigned to a project.
                If the user hasn't specified one, ask "Which project does this belong to?" before creating.
                Do not create orphan tasks — unassigned tasks become invisible in project views and rot.
                Exception: tasks explicitly labeled as personal/admin with no project context.
                """
            ),
            (
                "Summarize Before Archive",
                "always",
                "archivebox",
                "Knowledge Quality",
                """
                Before archiving a project or note, generate a 3-bullet outcome summary covering:
                1. What was accomplished
                2. Key decisions made (with dates if known)
                3. Any unresolved items or follow-ups
                Save this summary as a knowledge entry tagged with the item's name so archived work stays searchable.
                """
            ),
            (
                "Surface Related Context",
                "always",
                "link.circle",
                "Knowledge Discovery",
                """
                When a note is opened or created, search the knowledge base for related entries.
                If 2+ related items are found, surface them as "Related:" context.
                Helps prevent duplicate research and connects ideas across the knowledge base.
                """
            ),
            (
                "Auto-Escalate Overdue",
                "always",
                "exclamationmark.triangle",
                "Task Management",
                """
                Any task with a dueDate in the past and status not Done/Cancelled should be flagged.
                Escalate priority one level (Low→Medium→High→Urgent) and note "Auto-escalated: overdue as of YYYY-MM-DD".
                Notify the user of escalations so nothing silently rots.
                """
            )
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
