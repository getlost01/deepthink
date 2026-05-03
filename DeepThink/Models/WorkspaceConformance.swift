import Foundation

extension Note: WorkspaceItem {
    var wsTitle: String { title }
    var wsContent: String { content }
    var wsModifiedAt: Date { modifiedAt }
}

extension TaskItem: WorkspaceItem {
    var wsTitle: String { title }
    var wsContent: String { detail }
    var wsModifiedAt: Date { modifiedAt }
}
