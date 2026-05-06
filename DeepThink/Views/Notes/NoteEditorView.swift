import SwiftUI
import SwiftData

struct NoteEditorView: View {
    @Bindable var note: Note
    @FocusState private var titleFocused: Bool
    @State private var saveTask: Task<Void, Never>?
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Query(filter: #Predicate<Project> { !$0.isArchived }) private var projects: [Project]
    @State private var showSkillMenu = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: DS.Spacing.md) {
                TextField("Give your note a title...", text: $note.title)
                    .textFieldStyle(.plain)
                    .font(DS.Font.title)
                    .focused($titleFocused)

                Spacer()

                Text("\(note.wordCount) words")
                    .font(DS.Font.small)
                    .foregroundStyle(DS.Colors.textTertiary)

                Menu {
                    Button { note.project = nil; note.modifiedAt = Date() } label: { Text("None") }
                    Divider()
                    ForEach(projects) { project in
                        Button {
                            note.project = project
                            note.modifiedAt = Date()
                        } label: {
                            Label(project.name, systemImage: "folder")
                        }
                    }
                } label: {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "folder")
                            .font(.system(size: DS.IconSize.sm))
                            .foregroundStyle(note.project.map { Color(hex: $0.color) } ?? DS.Colors.textTertiary)
                        Text(note.project?.name ?? "Project")
                            .font(DS.Font.caption)
                            .foregroundStyle(note.project != nil ? DS.Colors.textPrimary : DS.Colors.textTertiary)
                    }
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, DS.Spacing.xs)
                    .background(DS.Colors.fill, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.sm)
                            .strokeBorder(DS.Colors.border, lineWidth: 1)
                    )
                }
                .buttonStyle(.plainPointer)
                .fixedSize()

                Menu {
                    ForEach(SkillFileService.shared.skills) { skill in
                        Button {
                            appState.navigate(to: .aiAssistant)
                            appState.pendingSkillExecution = skill
                        } label: {
                            Label(skill.name, systemImage: skill.icon)
                        }
                    }
                } label: {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "sparkles")
                            .font(.system(size: DS.IconSize.sm))
                        Text("Skills")
                            .font(DS.Font.caption)
                    }
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, DS.Spacing.xs)
                    .background(DS.Colors.fill, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.sm)
                            .strokeBorder(DS.Colors.border, lineWidth: 1)
                    )
                }
                .buttonStyle(.plainPointer)
                .fixedSize()
                .help("Run AI skill on this note")
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.vertical, DS.Spacing.md)

            Divider()

            RichMarkdownEditor(text: $note.content)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
        }
        .clipped()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onChange(of: note.content) { debouncedSave() }
        .onChange(of: note.title) { debouncedSave() }
        .onAppear {
            if note.title.isEmpty { titleFocused = true }
            publishNoteContext()
        }
        .onDisappear {
            appState.currentNoteContent = nil
            appState.currentNoteTitle = nil
            appState.currentNoteTags = []
        }
        .onChange(of: note.id) { publishNoteContext() }
    }

    private func debouncedSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            note.modifiedAt = Date()
            scheduleKnowledgeExtraction()
        }
    }

    @State private var extractionTask: Task<Void, Never>?

    private func scheduleKnowledgeExtraction() {
        extractionTask?.cancel()
        extractionTask = Task {
            try? await Task.sleep(for: .seconds(30))
            guard !Task.isCancelled else { return }
            await KnowledgeExtractionService.shared.extractFromNote(
                id: note.id, title: note.title, content: note.content
            )
        }
    }

    private func publishNoteContext() {
        appState.currentNoteContent = note.content
        appState.currentNoteTitle = note.title
        appState.currentNoteTags = note.tags.map(\.name)
    }
}
