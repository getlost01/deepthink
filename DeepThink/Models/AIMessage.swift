import Foundation

struct AIMessage: Identifiable {
    let id = UUID()
    let role: Role
    var content: String
    let timestamp = Date()
    var isStreaming: Bool = false

    enum Role {
        case user, assistant, error
    }
}
