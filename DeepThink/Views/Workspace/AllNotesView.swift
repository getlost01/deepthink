import SwiftUI
import SwiftData

struct AllNotesView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Note.modifiedAt, order: .reverse) private var notes: [Note]
    @Query private var projects: [Project]

    @State private var searchText: String = ""
    @State private var filterProjectID: UUID?
    @State private var noteToDelete: Note?
    @State private var showDeleteConfirm = false

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
        ResizableSplitView(minLeftWidth: 240, minRightWidth: 400) {
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
                        title: "No Notes Yet",
                        subtitle: searchText.isEmpty ? "Notes are where you capture ideas, meeting summaries, plans, or anything you want to remember." : "No notes match your search.",
                        hint: searchText.isEmpty ? "Try creating a note for your next meeting or idea" : nil
                    )
                } else {
                    List(filteredNotes, selection: Binding(
                        get: { appState.selectedNoteID },
                        set: { appState.selectedNoteID = $0 }
                    )) { note in
                        noteRow(note)
                            .tag(note.id)
                            .contextMenu {
                                Button { appState.selectedNoteID = note.id } label: {
                                    Label("Open", systemImage: "doc.text")
                                }
                                Divider()
                                Button(role: .destructive) { noteToDelete = note; showDeleteConfirm = true } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                    .listStyle(.plain)
                }
            }
            .background(DS.Colors.surface)
        } right: {
            if let note = selectedNote {
                NoteEditorView(note: note)
                    .id(note.id)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                DSEmptyState(
                    icon: "doc.text",
                    title: "Select a Note",
                    subtitle: "Pick a note from the list to start reading or editing."
                )
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .createNewNote)) { _ in
            let note = Note(title: "")
            modelContext.insert(note)
            appState.selectedNoteID = note.id
        }
        .confirmationDialog("Delete Note?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                if let note = noteToDelete {
                    deleteNote(note)
                    noteToDelete = nil
                }
            }
        } message: {
            Text("This will permanently delete \"\(noteToDelete?.title.isEmpty == false ? noteToDelete!.title : "Untitled")\".")
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
                            .font(DS.Font.small)
                            .foregroundStyle(Color(hex: project.color))
                    }

                    Text(note.modifiedAt.relativeFormatted)
                        .font(DS.Font.small)
                        .foregroundStyle(DS.Colors.textTertiary)
                }
            }

            Spacer()
        }
        .padding(.vertical, DS.Spacing.xs)
    }
}
