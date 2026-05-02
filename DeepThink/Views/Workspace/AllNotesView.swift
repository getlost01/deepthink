import SwiftUI
import SwiftData

struct AllNotesView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Note.modifiedAt, order: .reverse) private var notes: [Note]
    @Query private var projects: [Project]

    @State private var searchText: String = ""
    @State private var filterProjectID: UUID?

    private var filteredNotes: [Note] {
        var result = notes

        if let filterProjectID {
            result = result.filter { $0.project?.id == filterProjectID }
        }

        if !searchText.isEmpty {
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.content.localizedCaseInsensitiveContains(searchText)
            }
        }

        return result
    }

    private var selectedNote: Note? {
        guard let id = appState.selectedNoteID else { return nil }
        return notes.first { $0.id == id }
    }

    var body: some View {
        HSplitView {
            // Left panel: note list
            VStack(spacing: 0) {
                VStack(spacing: DS.Spacing.sm) {
                    DSSearchField(text: $searchText, placeholder: "Search notes...")

                    Picker("Project", selection: $filterProjectID) {
                        Text("All Projects").tag(nil as UUID?)
                        ForEach(projects) { project in
                            Text(project.name).tag(project.id as UUID?)
                        }
                    }
                    .pickerStyle(.menu)
                    .font(DS.Font.caption)
                }
                .padding(DS.Spacing.md)

                Divider()

                if filteredNotes.isEmpty {
                    DSEmptyState(
                        icon: "doc.text",
                        title: "No Notes",
                        subtitle: searchText.isEmpty ? "Create your first note to get started." : "No notes match your search."
                    )
                } else {
                    List(filteredNotes, selection: Binding(
                        get: { appState.selectedNoteID },
                        set: { appState.selectedNoteID = $0 }
                    )) { note in
                        noteRow(note)
                            .tag(note.id)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) { deleteNote(note) } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .contextMenu {
                                Button { appState.selectedNoteID = note.id } label: {
                                    Label("Open", systemImage: "doc.text")
                                }
                                Divider()
                                Button(role: .destructive) { deleteNote(note) } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                    .listStyle(.plain)
                }
            }
            .frame(minWidth: 240, idealWidth: 280, maxWidth: 360)
            .background(DS.Colors.surface)

            // Right panel: editor
            if let note = selectedNote {
                NoteEditorView(note: note)
                    .id(note.id)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                DSEmptyState(
                    icon: "doc.text",
                    title: "Select a Note",
                    subtitle: "Choose a note from the list to start editing."
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onReceive(NotificationCenter.default.publisher(for: .createNewNote)) { _ in
            let note = Note(title: "")
            modelContext.insert(note)
            appState.selectedNoteID = note.id
        }
    }

    private func deleteNote(_ note: Note) {
        if appState.selectedNoteID == note.id {
            appState.selectedNoteID = nil
        }
        modelContext.delete(note)
    }

    @ViewBuilder
    private func noteRow(_ note: Note) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            if note.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.orange)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(note.title.isEmpty ? "Untitled" : note.title)
                    .font(DS.Font.body)
                    .fontWeight(.medium)
                    .foregroundStyle(DS.Colors.textPrimary)
                    .lineLimit(1)

                HStack(spacing: DS.Spacing.xs) {
                    if let project = note.project {
                        Text(project.name)
                            .font(DS.Font.tiny)
                            .foregroundStyle(Color(hex: project.color))
                    }

                    Text(note.modifiedAt.relativeFormatted)
                        .font(DS.Font.tiny)
                        .foregroundStyle(DS.Colors.textTertiary)
                }
            }

            Spacer()
        }
        .padding(.vertical, DS.Spacing.xs)
    }
}
