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
            HStack(spacing: DS.Spacing.md) {
                TextField("Note title", text: $note.title)
                    .textFieldStyle(.plain)
                    .font(DS.Font.detailTitle)
                    .focused($titleFocused)

                Spacer()

                HStack(spacing: DS.Spacing.xs) {
                    DSToolbarButton(icon: "brain.head.profile", color: DS.Colors.accent, size: DS.IconSize.md) {
                        showAIMenu.toggle()
                    }
                    .popover(isPresented: $showAIMenu) {
                        AIActionsMenu(note: note, isProcessing: $aiProcessing)
                    }

                    if aiProcessing {
                        ProgressView()
                            .scaleEffect(0.6)
                    }

                    DSToolbarButton(icon: "clock.arrow.circlepath", size: DS.IconSize.md) {
                        showVersions = true
                    }
                    .help("Version History")

                    Picker("", selection: $showPreview) {
                        Image(systemName: "pencil").tag(false)
                        Image(systemName: "eye").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 80)
                }
            }
            .frame(height: DS.Layout.headerHeight)
            .padding(.horizontal, DS.Spacing.xl)

            Divider()

            if showPreview {
                MarkdownRendererView(markdown: note.content)
            } else {
                TextEditor(text: $note.content)
                    .font(.body.monospaced())
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.top, DS.Spacing.sm)
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
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    HStack {
                        Text("AI Result")
                            .font(DS.Font.heading)
                        Spacer()
                        Button("Apply") {
                            note.content += "\n\n---\n\n\(result)"
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(DS.Colors.accent)
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
                                .font(DS.Font.body)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            Text(result)
                                .font(DS.Font.body)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .frame(maxHeight: 300)
                }
                .padding(DS.Spacing.lg)
                .frame(width: 360)
            } else if let error {
                VStack(spacing: DS.Spacing.md) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 20, weight: .light))
                        .foregroundStyle(DS.Colors.error)
                    Text(error)
                        .font(DS.Font.body)
                        .foregroundStyle(DS.Colors.error)
                        .multilineTextAlignment(.center)
                }
                .padding(DS.Spacing.lg)
                .frame(width: 260)
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text("AI Actions")
                        .font(DS.Font.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(DS.Colors.textTertiary)
                        .textCase(.uppercase)
                        .padding(.horizontal, DS.Spacing.md)
                        .padding(.top, DS.Spacing.md)
                        .padding(.bottom, DS.Spacing.sm)

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
                    AIActionRow(title: "Continue Writing", icon: "arrow.right.doc.on.clipboard", color: .blue) {
                        await runAction {
                            try await ClaudeService.shared.query(
                                "Continue writing this document naturally from where it left off. Match the tone and style. Output only the continuation:\n\n\(note.content)",
                                systemPrompt: "You are a writing assistant. Continue the text naturally. Output only the new content."
                            )
                        }
                    }
                }
                .padding(.bottom, DS.Spacing.sm)
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
    @State private var isHovered = false

    var body: some View {
        Button {
            Task { await action() }
        } label: {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: DS.IconSize.sm, weight: .medium))
                    .foregroundStyle(color)
                    .frame(width: 20)
                Text(title)
                    .font(DS.Font.body)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: DS.IconSize.xs))
                    .foregroundStyle(DS.Colors.textTertiary)
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm + 2)
            .background(isHovered ? DS.Colors.hoverBg : .clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
