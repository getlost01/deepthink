import Foundation

struct AgentFile: Identifiable, Hashable {
    var id: String { filePath.path }
    var name: String
    var role: String
    var icon: String
    var model: String?
    var systemPrompt: String
    var skills: [String]
    var knowledgeScope: [String]
    var filePath: URL
    var isBuiltIn: Bool

    var filename: String { filePath.lastPathComponent }

    var modelDisplayName: String {
        guard let model else { return "Default" }
        if model.contains("haiku") { return "Haiku" }
        if model.contains("sonnet") { return "Sonnet" }
        if model.contains("opus") { return "Opus" }
        return model
    }
}
