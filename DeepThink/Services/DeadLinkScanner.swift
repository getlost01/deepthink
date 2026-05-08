import Foundation
import SwiftData

enum DeadLinkScanner {
    static func deadLinkUUIDs(in content: String, tasks: [TaskItem], notes: [Note], reminders: [Reminder]) -> Set<String> {
        var dead = Set<String>()
        let pattern = /deepthink:\/\/(task|note|reminder)\/([0-9A-Fa-f\-]{36})/
        for match in content.matches(of: pattern) {
            let type = String(match.1)
            let uuidStr = String(match.2)
            guard let uuid = UUID(uuidString: uuidStr) else { dead.insert(uuidStr); continue }
            let exists: Bool = switch type {
            case "task": tasks.contains { $0.id == uuid }
            case "note": notes.contains { $0.id == uuid }
            case "reminder": reminders.contains { $0.id == uuid }
            default: true
            }
            if !exists { dead.insert(uuidStr) }
        }
        return dead
    }
}
