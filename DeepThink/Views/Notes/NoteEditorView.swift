import SwiftUI
import SwiftData

struct NoteEditorView: View {
    @Bindable var note: Note
    @FocusState private var titleFocused: Bool
    @State private var saveTask: Task<Void, Never>?
    @Environment(\.modelContext) private var modelContext
    @State private var showPreview = false
    @State private var aiProcessing = false
    @State private var showAIMenu = false
    @State private var showVersions = false
    @State private var versionTimer: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                TextField("Note title", text: $note.title)
                    .textFieldStyle(.plain)
                    .font(.title)
                    .fontWeight(.semibold)
                    .focused($titleFocused)

                Spacer()

                HStack(spacing: 4) {
                    Button {
                        showAIMenu.toggle()
                    } label: {
                        Image(systemName: "brain.head.profile")
                            .foregroundStyle(.purple)
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showAIMenu) {
                        AIActionsMenu(note: note, isProcessing: $aiProcessing)
                    }

                    if aiProcessing {
                        ProgressView()
                            .scaleEffect(0.6)
                    }

                    Button {
                        showVersions = true
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                    .buttonStyle(.plain)
                    .help("Version History")

                    Picker("", selection: $showPreview) {
                        Image(systemName: "pencil").tag(false)
                        Image(systemName: "eye").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 80)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 8)

            Divider()
                .padding(.horizontal, 20)

            if showPreview {
                MarkdownRendererView(markdown: note.content)
            } else {
                TextEditor(text: $note.content)
                    .font(.body.monospaced())
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
            }
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

private struct AIActionsMenu: View {
    @Bindable var note: Note
    @Binding var isProcessing: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var result: String?
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let result {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("AI Result")
                            .font(.headline)
                        Spacer()
                        Button("Apply") {
                            note.content += "\n\n---\n\n\(result)"
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.purple)
                        .controlSize(.small)

                        Button("Copy") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(result, forType: .string)
                        }
                        .controlSize(.small)
                    }

                    ScrollView {
                        if let attributed = try? AttributedString(markdown: result, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
                            Text(attributed)
                                .font(.callout)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            Text(result)
                                .font(.callout)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .frame(maxHeight: 300)
                }
                .padding(12)
                .frame(width: 380)
            } else if let error {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
                .padding(12)
                .frame(width: 280)
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text("AI Actions")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                        .padding(.bottom, 4)

                    AIActionRow(title: "Summarize", icon: "text.justify.leading", color: .blue) {
                        await runAction { try await ClaudeService.shared.summarize(note.content) }
                    }
                    AIActionRow(title: "Extract Tasks", icon: "checklist", color: .orange) {
                        await runAction {
                            let tasks = try await ClaudeService.shared.suggestTasks(from: note.content)
                            return tasks.map { "- \($0)" }.joined(separator: "\n")
                        }
                    }
                    AIActionRow(title: "Improve Writing", icon: "pencil.and.outline", color: .green) {
                        await runAction { try await ClaudeService.shared.improveWriting(note.content) }
                    }
                    AIActionRow(title: "Continue Writing", icon: "arrow.right.doc.on.clipboard", color: .purple) {
                        await runAction {
                            try await ClaudeService.shared.query(
                                "Continue writing this document naturally from where it left off. Match the tone and style. Output only the continuation:\n\n\(note.content)",
                                systemPrompt: "You are a writing assistant. Continue the text naturally. Output only the new content."
                            )
                        }
                    }
                }
                .padding(.bottom, 8)
                .frame(width: 220)
            }
        }
    }

    private func runAction(_ action: @escaping () async throws -> String) async {
        isProcessing = true
        do {
            let r = try await action()
            await MainActor.run { result = r; isProcessing = false }
        } catch {
            await MainActor.run { self.error = error.localizedDescription; isProcessing = false }
        }
    }
}

private struct AIActionRow: View {
    let title: String
    let icon: String
    let color: Color
    let action: () async -> Void

    var body: some View {
        Button {
            Task { await action() }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .frame(width: 20)
                Text(title)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
