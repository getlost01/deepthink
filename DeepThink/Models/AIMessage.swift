import Foundation

struct AIMessage: Identifiable {
    let id = UUID()
    let role: Role
    var content: String
    let timestamp = Date()
    var isStreaming: Bool = false
    var tokenUsage: TokenUsage?

    enum Role {
        case user, assistant, error
    }
}

struct TokenUsage {
    var inputTokens: Int = 0
    var outputTokens: Int = 0
    var cacheReadTokens: Int = 0
    var cacheCreationTokens: Int = 0
    var costUSD: Double = 0
    var durationMs: Double = 0

    var totalTokens: Int { inputTokens + outputTokens }

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
