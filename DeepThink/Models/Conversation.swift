import Foundation
import SwiftData

@Model
final class UsageSession {
    var id: UUID = UUID()
    var startDate: Date = Date()
    var inputTokens: Int = 0
    var outputTokens: Int = 0
    var cacheReadTokens: Int = 0
    var queries: Int = 0
    var costUSD: Double = 0
    var durationMs: Double = 0

    init() {
        self.id = UUID()
        self.startDate = Date()
    }
}

@Model
final class Conversation {
    var id: UUID = UUID()
    var title: String = ""
    var agentName: String?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var isArchived: Bool = false

    var branchDataJSON: Data?

    @Relationship(deleteRule: .cascade) var messages: [ChatMessage] = []

    init(title: String, agentName: String? = nil) {
        self.id = UUID()
        self.title = title
        self.agentName = agentName
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var sortedMessages: [ChatMessage] {
        messages.sorted { $0.timestamp < $1.timestamp }
    }

    var lastMessage: ChatMessage? {
        sortedMessages.last
    }

    var messageCount: Int { messages.count }
}

@Model
final class ChatMessage {
    var id: UUID = UUID()
    var role: String = "user"
    var content: String = ""
    var timestamp: Date = Date()
    var inputTokens: Int = 0
    var outputTokens: Int = 0
    var cacheReadTokens: Int = 0
    var cacheCreationTokens: Int = 0
    var costUSD: Double = 0
    var durationMs: Double = 0

    var conversation: Conversation?

    init(role: String, content: String) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = Date()
    }

    var isUser: Bool { role == "user" }
    var isAssistant: Bool { role == "assistant" }
    var isError: Bool { role == "error" }

    var tokenUsage: TokenUsage? {
        guard inputTokens > 0 || outputTokens > 0 else { return nil }
        return TokenUsage(
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            cacheReadTokens: cacheReadTokens,
            cacheCreationTokens: cacheCreationTokens,
            costUSD: costUSD,
            durationMs: durationMs
        )
    }
}
