import Foundation

struct AIMessage: Identifiable {
    let id = UUID()
    let role: Role
    var content: String
    let timestamp: Date
    var isStreaming: Bool = false
    var tokenUsage: TokenUsage?

    init(role: Role, content: String, timestamp: Date = Date(), isStreaming: Bool = false, tokenUsage: TokenUsage? = nil) {
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.isStreaming = isStreaming
        self.tokenUsage = tokenUsage
    }

    enum Role {
        case user
        case assistant
        case error
    }
}

struct TokenUsage {
    var inputTokens: Int = 0
    var outputTokens: Int = 0
    var cacheReadTokens: Int = 0
    var cacheCreationTokens: Int = 0
    var costUSD: Double = 0
    var durationMs: Double = 0

    var totalTokens: Int {
        inputTokens + outputTokens
    }

    var formattedCost: String {
        costUSD < 0.01 ? String(format: "$%.4f", costUSD) : String(format: "$%.2f", costUSD)
    }

    var formattedDuration: String {
        durationMs < 1000 ? String(format: "%.0fms", durationMs) : String(format: "%.1fs", durationMs / 1000)
    }

    var formattedTokens: String {
        if totalTokens > 1000 {
            return String(format: "%.1fK tokens", Double(totalTokens) / 1000)
        }
        return "\(totalTokens) tokens"
    }
}

struct EditBranch: Identifiable {
    let id = UUID()
    let messages: [AIMessage]
}

struct BranchPoint {
    var branches: [EditBranch]
    var activeBranchIndex: Int
}

// MARK: - Branch Persistence

struct SerializedMessage: Codable {
    let role: String
    let content: String
    let timestamp: Date
}

struct SerializedBranch: Codable {
    let messages: [SerializedMessage]
}

struct SerializedBranchPoint: Codable {
    let index: Int
    let branches: [SerializedBranch]
    let activeBranchIndex: Int
}

enum BranchSerializer {
    static func serialize(_ branchPoints: [Int: BranchPoint]) -> Data? {
        let items = branchPoints.map { key, bp in
            SerializedBranchPoint(
                index: key,
                branches: bp.branches.map { branch in
                    SerializedBranch(messages: branch.messages.map { msg in
                        SerializedMessage(
                            role: msg.role == .user ? "user" : (msg.role == .error ? "error" : "assistant"),
                            content: msg.content,
                            timestamp: msg.timestamp
                        )
                    })
                },
                activeBranchIndex: bp.activeBranchIndex
            )
        }
        return try? JSONEncoder().encode(items)
    }

    static func deserialize(_ data: Data) -> [Int: BranchPoint] {
        guard let items = try? JSONDecoder().decode([SerializedBranchPoint].self, from: data) else { return [:] }
        var result: [Int: BranchPoint] = [:]
        for item in items {
            let branches = item.branches.map { sb in
                EditBranch(messages: sb.messages.map { sm in
                    let role: AIMessage.Role = sm.role == "user" ? .user : (sm.role == "error" ? .error : .assistant)
                    return AIMessage(role: role, content: sm.content, timestamp: sm.timestamp)
                })
            }
            result[item.index] = BranchPoint(branches: branches, activeBranchIndex: item.activeBranchIndex)
        }
        return result
    }
}
