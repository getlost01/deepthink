import Foundation
import SwiftUI

struct Command: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let shortcut: String?
    let section: String
    let action: () -> Void
}

@Observable
final class CommandPaletteState {
    var query: String = ""
    var selectedIndex: Int = 0
    private var commands: [Command] = []

    var filteredCommands: [Command] {
        if query.isEmpty { return commands }
        let lowered = query.lowercased()
        return commands.filter { $0.title.lowercased().contains(lowered) }
    }

    func registerCommands(_ commands: [Command]) {
        self.commands = commands
    }

    func moveUp() {
        guard selectedIndex > 0 else { return }
        selectedIndex -= 1
    }

    func moveDown() {
        guard selectedIndex < filteredCommands.count - 1 else { return }
        selectedIndex += 1
    }

    func executeSelected() -> Bool {
        let filtered = filteredCommands
        guard filtered.indices.contains(selectedIndex) else { return false }
        filtered[selectedIndex].action()
        return true
    }

    func reset() {
        query = ""
        selectedIndex = 0
    }
}
