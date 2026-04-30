import SwiftUI
import SwiftData

struct NoteInspectorView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query private var allNotes: [Note]
    @Query(filter: #Predicate<Project> { !$0.isArchived }) private var projects: [Project]

    private var selectedNote: Note? {
        guard let id = appState.selectedNoteID else { return nil }
        return allNotes.first { $0.id == id }
    }

    var body: some View {
        Group {
            if let note = selectedNote {
                NoteInspectorContent(note: note, projects: projects, allNotes: allNotes, modelContext: modelContext)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text")
                        .font(.title2)
                        .foregroundStyle(.tertiary)
                    Text("Select a note")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

private struct NoteInspectorContent: View {
    @Bindable var note: Note
    let projects: [Project]
    let allNotes: [Note]
    let modelContext: ModelContext
    @Environment(AppState.self) private var appState

    private var backlinks: [Note] {
        let links = BacklinkService.shared.backlinks(for: note.id, context: modelContext)
        let ids = Set(links.map(\.sourceNoteID))
        return allNotes.filter { ids.contains($0.id) }
    }

    private var outgoing: [Note] {
        let links = BacklinkService.shared.outgoingLinks(for: note.id, context: modelContext)
        let ids = Set(links.map(\.targetNoteID))
        return allNotes.filter { ids.contains($0.id) }
    }

    var body: some View {
        Form {
            Section("Details") {
                LabeledContent("Created", value: note.createdAt.shortFormatted)
                LabeledContent("Modified", value: note.modifiedAt.relativeFormatted)
                LabeledContent("Words", value: "\(note.wordCount)")
                LabeledContent("Characters", value: "\(note.characterCount)")
            }

            Section("Organization") {
                Picker("Project", selection: Binding(
                    get: { note.project },
                    set: { note.project = $0 }
                )) {
                    Text("None").tag(nil as Project?)
                    ForEach(projects) { project in
                        Text(project.name).tag(project as Project?)
                    }
                }

                Toggle("Pinned", isOn: $note.isPinned)
            }

            if !note.tags.isEmpty {
                Section("Tags") {
                    FlowLayout(spacing: 4) {
                        ForEach(note.tags) { tag in
                            TagChip(tag: tag)
                        }
                    }
                }
            }

            if !backlinks.isEmpty {
                Section("Backlinks") {
                    ForEach(backlinks) { linked in
                        Button {
                            appState.selectedNoteID = linked.id
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.turn.left.up")
                                    .font(.caption2)
                                    .foregroundStyle(.blue)
                                Text(linked.title.isEmpty ? "Untitled" : linked.title)
                                    .font(.caption)
                                    .lineLimit(1)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if !outgoing.isEmpty {
                Section("Links To") {
                    ForEach(outgoing) { linked in
                        Button {
                            appState.selectedNoteID = linked.id
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.turn.right.down")
                                    .font(.caption2)
                                    .foregroundStyle(.green)
                                Text(linked.title.isEmpty ? "Untitled" : linked.title)
                                    .font(.caption)
                                    .lineLimit(1)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Section {
                Text("Use [[Note Title]] in content to create links")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Inspector")
        .onAppear {
            BacklinkService.shared.updateLinks(for: note, allNotes: allNotes, context: modelContext)
        }
        .onChange(of: note.content) {
            BacklinkService.shared.updateLinks(for: note, allNotes: allNotes, context: modelContext)
        }
    }
}
