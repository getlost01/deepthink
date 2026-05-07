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
    @State private var showArchived = false

    private var pinnedNotes: [Note] { filteredNotes.filter { $0.isPinned } }
    private var unpinnedNotes: [Note] { filteredNotes.filter { !$0.isPinned } }

    private var filteredNotes: [Note] {
        var result = notes.filter { showArchived ? $0.isArchived : !$0.isArchived }

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
                    HStack(spacing: DS.Spacing.sm) {
                        DSSearchField(text: $searchText, placeholder: "Search notes...")
                        DSArchiveButton(isOn: showArchived, count: notes.filter { $0.isArchived }.count) { showArchived.toggle() }
                    }

                    HStack {
                        Picker(selection: $filterProjectID) {
                            Text("All Projects").tag(nil as UUID?)
                            ForEach(projects) { project in
                                Text(project.name).tag(project.id as UUID?)
                            }
                        } label: { EmptyView() }
                        .pickerStyle(.menu)
                        .font(DS.Font.caption)
                        .fixedSize()

                        Spacer()
                    }
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
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            if !pinnedNotes.isEmpty {
                                HStack(spacing: DS.Spacing.xs) {
                                    Image(systemName: "pin.fill")
                                        .font(.system(size: DS.IconSize.xs))
                                    Text("Pinned")
                                        .font(DS.Font.small)
                                }
                                .foregroundStyle(DS.Colors.textTertiary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, DS.Spacing.md)
                                .padding(.top, DS.Spacing.sm)
                                .padding(.bottom, DS.Spacing.xs)

                                ForEach(pinnedNotes) { note in
                                    let isSelected = appState.selectedNoteID == note.id
                                    Button { appState.selectedNoteID = note.id } label: {
                                        noteRow(note)
                                            .padding(.horizontal, DS.Spacing.sm)
                                            .padding(.vertical, DS.Spacing.xxs)
                                            .background(isSelected ? DS.Colors.accentFill : .clear)
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plainPointer)
                                    .contextMenu { noteContextMenu(note) }
                                    Divider().padding(.horizontal, DS.Spacing.sm)
                                }
                            }

                            ForEach(unpinnedNotes) { note in
                                let isSelected = appState.selectedNoteID == note.id
                                Button { appState.selectedNoteID = note.id } label: {
                                    noteRow(note)
                                        .padding(.horizontal, DS.Spacing.sm)
                                        .padding(.vertical, DS.Spacing.xxs)
                                        .background(isSelected ? DS.Colors.accentFill : .clear)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plainPointer)
                                .contextMenu { noteContextMenu(note) }
                                Divider().padding(.horizontal, DS.Spacing.sm)
                            }
                        }
                    }
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

    @ViewBuilder
    private func noteContextMenu(_ note: Note) -> some View {
        Button { appState.selectedNoteID = note.id } label: {
            Label("Open", systemImage: "doc.text")
        }
        Button {
            note.isPinned.toggle()
            note.modifiedAt = Date()
        } label: {
            Label(note.isPinned ? "Unpin" : "Pin", systemImage: note.isPinned ? "pin.slash" : "pin")
        }
        Button {
            note.isArchived.toggle()
            note.modifiedAt = Date()
        } label: {
            Label(note.isArchived ? "Unarchive" : "Archive", systemImage: note.isArchived ? "archivebox" : "archivebox.fill")
        }
        Divider()
        Button(role: .destructive) { noteToDelete = note; showDeleteConfirm = true } label: {
            Label("Delete", systemImage: "trash")
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
                    .font(.system(size: DS.IconSize.xs))
                    .foregroundStyle(DS.Colors.amber)
            }

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(note.title.isEmpty ? "Untitled" : note.title)
                    .font(DS.Font.body)
                    .fontWeight(.medium)
                    .foregroundStyle(DS.Colors.textPrimary)
                    .lineLimit(1)

                if !note.content.isEmpty {
                    Text(note.content.prefix(60).replacingOccurrences(of: "\n", with: " "))
                        .font(DS.Font.small)
                        .foregroundStyle(DS.Colors.textTertiary)
                        .lineLimit(1)
                }

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
        .padding(.vertical, DS.Spacing.sm)
    }
}
