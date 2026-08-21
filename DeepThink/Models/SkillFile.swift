import Foundation

struct SkillFile: Identifiable, Hashable {
    var id: String {
        filePath.path
    }

    var name: String
    var trigger: String
    var icon: String
    var model: String?
    var category: String
    var systemPrompt: String
    var promptTemplate: String
    var filePath: URL
    var isBuiltIn: Bool
    var isPinned: Bool = false
    var knowledgeScope: [String] = []
    var command: String = ""

    var filename: String {
        filePath.lastPathComponent
    }

    var commandName: String {
        if !command.isEmpty { return command }
        let slug = name.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "[^a-z0-9\\-]", with: "", options: .regularExpression)
        guard slug.contains(where: { $0.isLetter || $0.isNumber }) else {
            return filePath.deletingPathExtension().lastPathComponent
        }
        return slug
    }
}

struct RuleFile: Identifiable, Hashable {
    var id: String {
        filePath.path
    }

    var name: String
    var trigger: String
    var icon: String
    var category: String
    var instruction: String
    var filePath: URL
    var isBuiltIn: Bool
    var priority: Int = 0
    var isDisabled: Bool = false

    var filename: String {
        filePath.lastPathComponent
    }
}
