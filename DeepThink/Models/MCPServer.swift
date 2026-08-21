import Foundation
import SwiftData

@Model
final class MCPServer {
    var id: UUID = UUID()
    var name: String = ""
    var command: String = ""
    var args: String = ""
    var envVars: String = ""
    var isEnabled: Bool = true
    var category: String = "General"
    var serverDescription: String = ""
    var addedAt: Date = Date()
    var isCore: Bool = false

    init(name: String, command: String, args: String = "", envVars: String = "", category: String = "General", description: String = "", isCore: Bool = false) {
        id = UUID()
        self.name = name
        self.command = command
        self.args = args
        self.envVars = envVars
        self.category = category
        serverDescription = description
        isEnabled = true
        addedAt = Date()
        self.isCore = isCore
    }

    var argsArray: [String] {
        args.split(separator: " ").map(String.init)
    }

    var envDict: [String: String] {
        var dict: [String: String] = [:]
        for line in envVars.split(separator: "\n") {
            let parts = line.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else { continue }
            let key = parts[0].trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty else { continue }
            dict[key] = parts[1].trimmingCharacters(in: .whitespaces)
        }
        return dict
    }

    var mcpConfigJSON: [String: Any] {
        var config: [String: Any] = [
            "command": command,
            "args": argsArray
        ]
        if !envDict.isEmpty {
            config["env"] = envDict
        }
        return config
    }
}

struct MCPToolResult: Identifiable {
    let id = UUID()
    let toolName: String
    let result: String
    let timestamp: Date
    let duration: TimeInterval
    let isError: Bool
}
