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

    var filename: String { filePath.lastPathComponent }
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
