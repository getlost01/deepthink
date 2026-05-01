import SwiftUI
import SwiftData

struct NoteListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Query(sort: \Note.modifiedAt, order: .reverse) private var notes: [Note]
    @State private var searchText = ""
    @State private var debouncedSearch = ""
    @State private var searchTask: Task<Void, Never>?

    private var filteredNotes: [Note] {
        if debouncedSearch.isEmpty { return notes }
        let lowered = debouncedSearch.lowercased()
        return notes.filter {
            $0.title.lowercased().contains(lowered) ||
            $0.content.lowercased().contains(lowered)
        }
    }

    var body: some View {
        @Bindable var appState = appState

        VStack(spacing: 0) {
            DSPageHeader(title: "Notes") {
                DSToolbarButton(icon: "square.and.pencil", color: DS.Colors.accent, size: DS.IconSize.md) {
                    createNote()
                }
                .help("New Note (⌘N)")
            }

            DSSearchField(text: $searchText, placeholder: "Search notes...")
                .padding(.horizontal, DS.Spacing.md)
                .padding(.bottom, DS.Spacing.sm)

            Divider()

            List(selection: $appState.selectedNoteID) {
                ForEach(filteredNotes) { note in
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        HStack(spacing: DS.Spacing.xs) {
                            if note.isPinned {
                                Image(systemName: "pin.fill")
                                    .font(.system(size: DS.IconSize.xs))
                                    .foregroundStyle(DS.Colors.warning)
                            }
                            Text(note.title.isEmpty ? "Untitled" : note.title)
                                .font(DS.Font.body)
                                .fontWeight(.medium)
                                .lineLimit(1)
                        }
                        HStack {
                            Text(note.firstLine)
                                .font(DS.Font.caption)
                                .foregroundStyle(DS.Colors.textSecondary)
                                .lineLimit(1)
                            Spacer()
                            Text(note.modifiedAt.relativeFormatted)
                                .font(DS.Font.tiny)
                                .foregroundStyle(DS.Colors.textTertiary)
                        }
                    }
                    .padding(.vertical, DS.Spacing.xs)
                    .tag(note.id)
                    .contextMenu {
                        Button(note.isPinned ? "Unpin" : "Pin") {
                            note.isPinned.toggle()
                        }
                        Divider()
                        Button("Delete", role: .destructive) {
                            deleteNote(note)
                        }
                    }
                }
                .onDelete(perform: deleteNotes)
            }
            .listStyle(.inset)
            .overlay {
                if filteredNotes.isEmpty {
                    DSEmptyState(
                        icon: "doc.text",
                        title: "No Notes Yet",
                        subtitle: "Notes are great for capturing ideas, meeting notes, or documentation",
                        action: createNote,
                        actionTitle: "New Note"
                    )
                }
            }
        }
        .onChange(of: searchText) {
            searchTask?.cancel()
            searchTask = Task {
                try? await Task.sleep(for: .milliseconds(200))
                guard !Task.isCancelled else { return }
                debouncedSearch = searchText
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .createNewNote)) { _ in
            createNote()
        }
    }

    private func createNote() {
        let note = Note(title: "Untitled Note")
        modelContext.insert(note)
        appState.selectedNoteID = note.id
    }

    private func deleteNote(_ note: Note) {
        if appState.selectedNoteID == note.id { appState.selectedNoteID = nil }
        modelContext.delete(note)
    }

    private func deleteNotes(at offsets: IndexSet) {
        for index in offsets { deleteNote(filteredNotes[index]) }
    }
}
