import SwiftData
import SwiftUI

struct NoteInspectorView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query private var allNotes: [Note]
    @Query private var projects: [Project]

    private var selectedNote: Note? {
        guard let id = appState.selectedNoteID else { return nil }
        return allNotes.first { $0.id == id }
    }

    var body: some View {
        Group {
            if let note = selectedNote {
                NoteInspectorContent(note: note, projects: projects, allNotes: allNotes, modelContext: modelContext)
            } else {
                VStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "doc.text")
                        .font(.system(size: DS.IconSize.xxl, weight: .light))
                        .foregroundStyle(DS.Colors.textTertiary)
                    Text("Select a note")
                        .foregroundStyle(DS.Colors.textSecondary)
                        .font(DS.Font.caption)
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

                if let project = note.project {
                    Button {
                        appState.navigateToProject(project.id)
                    } label: {
                        HStack(spacing: DS.Spacing.sm) {
                            Circle()
                                .fill(Color(hex: project.color))
                                .frame(width: 8, height: 8)
                            Text("Go to \(project.name)")
                                .font(DS.Font.caption)
                                .foregroundStyle(DS.Colors.accent)
                            Spacer()
                            Image(systemName: "arrow.right")
                                .font(.system(size: DS.IconSize.sm))
                                .foregroundStyle(DS.Colors.textTertiary)
                        }
                    }
                    .buttonStyle(.plainPointer)
                }

                Toggle("Pinned", isOn: $note.isPinned)
                Toggle("Archived", isOn: $note.isArchived)
            }

            if !note.tags.isEmpty {
                Section("Tags") {
                    FlowLayout(spacing: DS.Spacing.xs) {
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
                            HStack(spacing: DS.Spacing.sm) {
                                Image(systemName: "arrow.turn.left.up")
                                    .font(.system(size: DS.IconSize.sm))
                                    .foregroundStyle(DS.Colors.accent)
                                Text(linked.title.isEmpty ? "Untitled" : linked.title)
                                    .font(DS.Font.caption)
                                    .lineLimit(1)
                            }
                        }
                        .buttonStyle(.plainPointer)
                    }
                }
            }

            if !outgoing.isEmpty {
                Section("Links To") {
                    ForEach(outgoing) { linked in
                        Button {
                            appState.selectedNoteID = linked.id
                        } label: {
                            HStack(spacing: DS.Spacing.sm) {
                                Image(systemName: "arrow.turn.right.down")
                                    .font(.system(size: DS.IconSize.sm))
                                    .foregroundStyle(DS.Colors.success)
                                Text(linked.title.isEmpty ? "Untitled" : linked.title)
                                    .font(DS.Font.caption)
                                    .lineLimit(1)
                            }
                        }
                        .buttonStyle(.plainPointer)
                    }
                }
            }

            Section {
                Text("Use [[Note Title]] in content to create links")
                    .font(DS.Font.small)
                    .foregroundStyle(DS.Colors.textTertiary)
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
