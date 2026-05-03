import Foundation

struct SkillFile: Identifiable, Hashable {
    var id: String { filePath.path }
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

    var filename: String { filePath.lastPathComponent }

    var commandName: String {
        name.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "[^a-z0-9\\-]", with: "", options: .regularExpression)
    }
}

struct RuleFile: Identifiable, Hashable {
    var id: String { filePath.path }
    var name: String
    var trigger: String
    var icon: String
    var category: String
    var instruction: String
    var filePath: URL
    var isBuiltIn: Bool

    var filename: String { filePath.lastPathComponent }
}
