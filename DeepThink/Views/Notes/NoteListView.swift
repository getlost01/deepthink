import SwiftData
import SwiftUI

struct NoteListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Query(sort: \Note.modifiedAt, order: .reverse) private var notes: [Note]
    @State private var searchText = ""
    @State private var debouncedSearch = ""
    @State private var searchTask: Task<Void, Never>?
    @State private var showArchived = false
    @Query(filter: #Predicate<Project> { !$0.isArchived }) private var allProjects: [Project]

    private var filteredNotes: [Note] {
        var result = notes.filter { showArchived ? $0.isArchived : !$0.isArchived }
        if let projectID = appState.filterProjectID {
            result = result.filter { $0.project?.id == projectID }
        }
        if !debouncedSearch.isEmpty {
            let lowered = debouncedSearch.lowercased()
            result = result.filter {
                $0.title.lowercased().contains(lowered) ||
                    $0.content.lowercased().contains(lowered)
            }
        }
        return result
    }

    private var filterProjectName: String? {
        guard let id = appState.filterProjectID else { return nil }
        return allProjects.first { $0.id == id }?.name
    }

    var body: some View {
        @Bindable var appState = appState

        VStack(spacing: 0) {
            HStack(spacing: DS.Spacing.sm) {
                DSSearchField(text: $searchText, placeholder: "Search notes...")
                DSArchiveButton(isOn: showArchived, count: notes.count(where: { $0.isArchived })) { showArchived.toggle() }
                DSAddButton {
                    createNote()
                }
                .help("New Note (⌘N)")
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.sm)

            Divider()

            if let projectName = filterProjectName {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: DS.IconSize.sm))
                        .foregroundStyle(DS.Colors.accent)
                    Text(projectName)
                        .font(DS.Font.caption)
                        .fontWeight(.medium)
                    Button {
                        appState.filterByProject(nil)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: DS.IconSize.sm))
                            .foregroundStyle(DS.Colors.textTertiary)
                    }
                    .buttonStyle(.plainPointer)
                    Spacer()
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.bottom, DS.Spacing.sm)
            }

            Divider()

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredNotes) { note in
                        let isSelected = appState.selectedNoteID == note.id
                        Button {
                            appState.selectedNoteID = note.id
                        } label: {
                            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                                HStack(spacing: DS.Spacing.xs) {
                                    if note.isPinned {
                                        Image(systemName: "pin.fill")
                                            .font(.system(size: DS.IconSize.sm))
                                            .foregroundStyle(DS.Colors.warning)
                                    }
                                    if note.isArchived {
                                        Image(systemName: "archivebox")
                                            .font(.system(size: DS.IconSize.xs, weight: .medium))
                                            .foregroundStyle(DS.Colors.textTertiary)
                                    }
                                    Text(note.title.isEmpty ? "Untitled" : note.title)
                                        .font(DS.Font.body)
                                        .fontWeight(.medium)
                                        .lineLimit(1)
                                        .foregroundStyle(DS.Colors.textPrimary)
                                }
                                HStack {
                                    Text(note.firstLine)
                                        .font(DS.Font.caption)
                                        .foregroundStyle(DS.Colors.textSecondary)
                                        .lineLimit(1)
                                    Spacer()
                                    Text(note.modifiedAt.relativeFormatted)
                                        .font(DS.Font.small)
                                        .foregroundStyle(DS.Colors.textTertiary)
                                }
                            }
                            .padding(.vertical, DS.Spacing.sm)
                            .padding(.horizontal, DS.Spacing.sm)
                            .background(isSelected ? DS.Colors.accentFill : .clear)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plainPointer)
                        .contextMenu {
                            Button(note.isPinned ? "Unpin" : "Pin") {
                                note.isPinned.toggle()
                                note.modifiedAt = Date()
                                try? modelContext.save()
                            }
                            Button(note.isArchived ? "Unarchive" : "Archive") {
                                note.isArchived.toggle()
                                note.modifiedAt = Date()
                                try? modelContext.save()
                            }
                            Divider()
                            Button("Delete", role: .destructive) {
                                deleteNote(note)
                            }
                        }
                        if note.id != filteredNotes.last?.id {
                            Divider()
                        }
                    }
                }
            }
            .onKeyPress(.upArrow) { moveSelection(-1); return .handled }
            .onKeyPress(.downArrow) { moveSelection(1); return .handled }
            .onKeyPress(.escape) { appState.selectedNoteID = nil; return .handled }
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
        .onChange(of: appState.selectedNoteID) { _, id in
            guard let id, !showArchived else { return }
            if let note = notes.first(where: { $0.id == id }), note.isArchived {
                showArchived = true
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
        for index in offsets {
            deleteNote(filteredNotes[index])
        }
    }

    private func moveSelection(_ direction: Int) {
        guard !filteredNotes.isEmpty else { return }
        if let current = appState.selectedNoteID,
           let idx = filteredNotes.firstIndex(where: { $0.id == current })
        {
            let next = min(max(idx + direction, 0), filteredNotes.count - 1)
            appState.selectedNoteID = filteredNotes[next].id
        } else {
            appState.selectedNoteID = filteredNotes[direction > 0 ? 0 : filteredNotes.count - 1].id
        }
    }
}
