import Foundation
import SwiftUI

@Observable
final class AppState {
    var selectedSection: SidebarSection? = .home
    var showCommandPalette: Bool = false
    var searchQuery: String = ""
    var pendingChatMessage: String?

    var selectedNoteID: UUID?
    var selectedTaskID: UUID?
    var selectedProjectID: UUID?

    func navigate(to section: SidebarSection) {
        selectedSection = section
    }

    func toggleCommandPalette() {
        withAnimation(.spring(duration: 0.25)) {
            showCommandPalette.toggle()
        }
    }
}
