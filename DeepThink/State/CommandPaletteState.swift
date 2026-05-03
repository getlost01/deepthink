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

struct WorkspaceSearchItem: Identifiable {
    let id: UUID
    let title: String
    let subtitle: String
    let icon: String
    let type: ItemType
    let action: () -> Void

    enum ItemType: String {
        case note = "Notes"
        case task = "Tasks"
        case project = "Projects"
        case knowledge = "Knowledge"
    }
}

struct PaletteSection: Identifiable {
    let title: String
    let items: [PaletteItem]
    var id: String { title }
}

enum PaletteItem: Identifiable {
    case command(Command)
    case workspaceItem(WorkspaceSearchItem)

    var id: UUID {
        switch self {
        case .command(let c): c.id
        case .workspaceItem(let w): w.id
        }
    }

    var title: String {
        switch self {
        case .command(let c): c.title
        case .workspaceItem(let w): w.title
        }
    }
}

@Observable
final class CommandPaletteState {
    var query: String = ""
    var selectedIndex: Int = 0
    private var commands: [Command] = []
    var workspaceItems: [WorkspaceSearchItem] = []

    var sections: [PaletteSection] {
        if query.isEmpty {
            let commandSection = PaletteSection(title: "Commands", items: commands.prefix(8).map { .command($0) })
            return [commandSection]
        }

        var result: [PaletteSection] = []

        let matchedCommands = commands.filter { fuzzyMatch(query, in: $0.title) }
        if !matchedCommands.isEmpty {
            result.append(PaletteSection(title: "Commands", items: matchedCommands.map { .command($0) }))
        }

        let grouped = Dictionary(grouping: matchedWorkspaceItems) { $0.type }
        for type in [WorkspaceSearchItem.ItemType.note, .task, .project, .knowledge] {
            if let items = grouped[type], !items.isEmpty {
                result.append(PaletteSection(title: type.rawValue, items: items.prefix(5).map { .workspaceItem($0) }))
            }
        }

        return result
    }

    var allFlatItems: [PaletteItem] {
        sections.flatMap(\.items)
    }

    private var matchedWorkspaceItems: [WorkspaceSearchItem] {
        guard !query.isEmpty else { return [] }
        return workspaceItems.filter { fuzzyMatch(query, in: $0.title) || fuzzyMatch(query, in: $0.subtitle) }
    }

    var filteredCommands: [Command] {
        if query.isEmpty { return commands }
        return commands.filter { fuzzyMatch(query, in: $0.title) }
    }

    func registerCommands(_ commands: [Command]) {
        self.commands = commands
    }

    func moveUp() {
        guard selectedIndex > 0 else { return }
        selectedIndex -= 1
    }

    func moveDown() {
        let total = allFlatItems.count
        guard selectedIndex < total - 1 else { return }
        selectedIndex += 1
    }

    func executeSelected() -> Bool {
        let items = allFlatItems
        guard items.indices.contains(selectedIndex) else { return false }
        switch items[selectedIndex] {
        case .command(let cmd): cmd.action()
        case .workspaceItem(let item): item.action()
        }
        return true
    }

    func reset() {
        query = ""
        selectedIndex = 0
    }

    private func fuzzyMatch(_ query: String, in target: String) -> Bool {
        let q = query.lowercased()
        let t = target.lowercased()
        if t.contains(q) { return true }
        var qIdx = q.startIndex
        for char in t {
            if char == q[qIdx] {
                qIdx = q.index(after: qIdx)
                if qIdx == q.endIndex { return true }
            }
        }
        return false
    }
}
