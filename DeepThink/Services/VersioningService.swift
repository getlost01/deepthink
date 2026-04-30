import Foundation
import SwiftData

@Observable
final class VersioningService {
    static let shared = VersioningService()
    private var lastSnapshots: [UUID: String] = [:]

    func snapshotIfChanged(note: Note, context: ModelContext) {
        let currentContent = "\(note.title)\n\(note.content)"
        if let last = lastSnapshots[note.id], last == currentContent { return }

        let nID = note.id
        let descriptor = FetchDescriptor<NoteVersion>(
            predicate: #Predicate<NoteVersion> { v in v.noteID == nID },
            sortBy: [SortDescriptor(\.versionNumber, order: .reverse)]
        )
        let existing = (try? context.fetch(descriptor)) ?? []
        let nextVersion = (existing.first?.versionNumber ?? 0) + 1

        let version = NoteVersion(note: note, versionNumber: nextVersion)
        context.insert(version)

        lastSnapshots[note.id] = currentContent

        if existing.count > 50 {
            for old in existing.suffix(from: 50) {
                context.delete(old)
            }
        }
    }

    func versions(for noteID: UUID, context: ModelContext) -> [NoteVersion] {
        let nID = noteID
        let descriptor = FetchDescriptor<NoteVersion>(
            predicate: #Predicate<NoteVersion> { v in v.noteID == nID },
            sortBy: [SortDescriptor(\.versionNumber, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func restore(note: Note, from version: NoteVersion, context: ModelContext) {
        snapshotIfChanged(note: note, context: context)
        note.title = version.title
        note.content = version.content
        note.modifiedAt = Date()
    }
}
