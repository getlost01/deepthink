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

struct EditBranch: Identifiable {
    let id = UUID()
    let messages: [AIMessage]
}

struct BranchPoint {
    var branches: [EditBranch]
    var activeBranchIndex: Int
}
