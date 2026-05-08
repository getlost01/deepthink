import Foundation
import SwiftData

final class BacklinkService {
    static let shared = BacklinkService()

    private let linkPattern = /\[\[([^\]]+)\]\]/

    func extractLinks(from content: String) -> [String] {
        content.matches(of: linkPattern).map { String($0.1) }
    }

    func updateLinks(for note: Note, allNotes: [Note], context: ModelContext) {
        let referenced = extractLinks(from: note.content)

        let noteID = note.id
        let existingDescriptor = FetchDescriptor<NoteLink>(
            predicate: #Predicate<NoteLink> { link in link.sourceNoteID == noteID }
        )
        let existing = (try? context.fetch(existingDescriptor)) ?? []
        for link in existing {
            context.delete(link)
        }

        for refTitle in referenced {
            let lowered = refTitle.lowercased()
            if let target = allNotes.first(where: { $0.title.lowercased() == lowered }) {
                let link = NoteLink(sourceNoteID: note.id, targetNoteID: target.id)
                context.insert(link)
            }
        }
    }

    func backlinks(for noteID: UUID, context: ModelContext) -> [NoteLink] {
        let targetID = noteID
        let descriptor = FetchDescriptor<NoteLink>(
            predicate: #Predicate<NoteLink> { link in link.targetNoteID == targetID }
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func outgoingLinks(for noteID: UUID, context: ModelContext) -> [NoteLink] {
        let sourceID = noteID
        let descriptor = FetchDescriptor<NoteLink>(
            predicate: #Predicate<NoteLink> { link in link.sourceNoteID == sourceID }
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    struct GraphNode: Identifiable {
        let id: UUID
        let title: String
        var connections: [UUID]
    }

    func buildGraph(notes: [Note], context: ModelContext) -> [GraphNode] {
        var nodes: [UUID: GraphNode] = [:]

        for note in notes {
            nodes[note.id] = GraphNode(id: note.id, title: note.title, connections: [])
        }

        let allLinks = (try? context.fetch(FetchDescriptor<NoteLink>())) ?? []
        for link in allLinks {
            nodes[link.sourceNoteID]?.connections.append(link.targetNoteID)
            nodes[link.targetNoteID]?.connections.append(link.sourceNoteID)
        }

        return Array(nodes.values).filter { !$0.connections.isEmpty }
    }

    // MARK: - Knowledge Entry Links (Feature 8)

    func knowledgeEntriesLinkedTo(note: Note) -> [KnowledgeEntry] {
        let titleLower = note.title.lowercased()
        let contentWords = Set(
            note.content.lowercased()
                .components(separatedBy: .whitespacesAndNewlines)
                .filter { $0.count > 3 }
        )

        return KnowledgeService.shared.entries.filter { entry in
            let entryTitleLower = entry.title.lowercased()
            if note.content.lowercased().contains(entryTitleLower), entryTitleLower.count > 4 { return true }
            if entry.content.lowercased().contains(titleLower), titleLower.count > 4 { return true }
            let entryWords = Set(entry.tags.map { $0.lowercased() })
            if !entryWords.isEmpty, !entryWords.intersection(contentWords).isEmpty { return true }
            return false
        }
    }

    func deepLinkBacklinks(forType type: String, id: UUID, in notes: [Note]) -> [Note] {
        let uuidStr = id.uuidString.lowercased()
        let pattern = "deepthink://\(type)/\(uuidStr)"
        return notes.filter { $0.content.range(of: pattern, options: .caseInsensitive) != nil }
    }

    func notesLinkedTo(entry: KnowledgeEntry, notes: [Note]) -> [Note] {
        let entryTitleLower = entry.title.lowercased()
        let entryTags = Set(entry.tags.map { $0.lowercased() })

        return notes.filter { note in
            if note.content.lowercased().contains(entryTitleLower), entryTitleLower.count > 4 { return true }
            if entry.content.lowercased().contains(note.title.lowercased()), note.title.count > 4 { return true }
            let noteWords = Set(
                note.content.lowercased()
                    .components(separatedBy: .whitespacesAndNewlines)
                    .filter { $0.count > 3 }
            )
            if !entryTags.isEmpty, !entryTags.intersection(noteWords).isEmpty { return true }
            return false
        }
    }
}
