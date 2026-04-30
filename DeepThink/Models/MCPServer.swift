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

    init(name: String, command: String, args: String = "", envVars: String = "", category: String = "General", description: String = "") {
        self.id = UUID()
        self.name = name
        self.command = command
        self.args = args
        self.envVars = envVars
        self.category = category
        self.serverDescription = description
        self.isEnabled = true
        self.addedAt = Date()
    }

    var argsArray: [String] {
        args.split(separator: " ").map(String.init)
    }

    var envDict: [String: String] {
        var dict: [String: String] = [:]
        for line in envVars.split(separator: "\n") {
            let parts = line.split(separator: "=", maxSplits: 1)
            if parts.count == 2 {
                dict[String(parts[0])] = String(parts[1])
            }
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
