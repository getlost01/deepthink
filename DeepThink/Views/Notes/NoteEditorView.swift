import SwiftUI
import SwiftData

struct NoteEditorView: View {
    @Bindable var note: Note
    @FocusState private var titleFocused: Bool
    @State private var saveTask: Task<Void, Never>?
    @Environment(\.modelContext) private var modelContext
    @State private var showVersions = false
    @State private var versionTimer: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: DS.Spacing.md) {
                TextField("Give your note a title...", text: $note.title)
                    .textFieldStyle(.plain)
                    .font(DS.Font.title)
                    .focused($titleFocused)

                Spacer()

                DSToolbarButton(icon: "clock.arrow.circlepath", size: DS.IconSize.md) {
                    showVersions = true
                }
                .help("Version History")
            }
            .frame(height: DS.Layout.toolbarHeight)
            .padding(.horizontal, DS.Spacing.xl)

            RichMarkdownEditor(text: $note.content)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onChange(of: note.content) { debouncedSave() }
        .onChange(of: note.title) { debouncedSave() }
        .sheet(isPresented: $showVersions) {
            NoteVersionsView(note: note)
        }
        .onAppear { startVersionTimer() }
        .onDisappear { versionTimer?.cancel() }
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

    private func startVersionTimer() {
        versionTimer = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                guard !Task.isCancelled else { break }
                await MainActor.run {
                    VersioningService.shared.snapshotIfChanged(note: note, context: modelContext)
                }
            }
        }
    }
}
