import SwiftUI
import SwiftTerm

struct DeepThinkTerminalView: View {
    @State private var sessions: [TerminalSession] = []
    @State private var activeSessionID: UUID?
    @State private var isAnalyzing = false
    @State private var analysisResult: String?
    @State private var showAnalysisSheet = false

    private var activeSession: TerminalSession? {
        sessions.first { $0.id == activeSessionID }
    }

    var body: some View {
        VStack(spacing: 0) {
            DSToolbarBar {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 2) {
                        ForEach(sessions) { session in
                            TerminalTabButton(
                                session: session,
                                isActive: session.id == activeSessionID,
                                canClose: sessions.count > 1,
                                onSelect: { activeSessionID = session.id },
                                onClose: { closeSession(session.id) }
                            )
                        }

                        DSToolbarButton(icon: "plus", color: DS.Colors.textTertiary, size: DS.IconSize.sm) {
                            addSession()
                        }
                    }
                }

                Spacer()

                HStack(spacing: DS.Spacing.sm) {
                    DSToolbarButton(icon: "wand.and.rays", color: DS.Colors.textTertiary, size: DS.IconSize.sm) {
                        analyzeOutput()
                    }
                    .help("Analyze terminal output with AI")
                    .disabled(isAnalyzing)

                    if isAnalyzing {
                        ProgressView()
                            .scaleEffect(0.6)
                    }
                }
            }

            Divider()

            if let session = activeSession {
                TerminalHostView(session: session)
                    .id(session.id)
                    .padding(DS.Spacing.sm)
                    .background(DS.Colors.terminal)
            }
        }
        .onAppear {
            if sessions.isEmpty {
                addSession()
            }
        }
        .sheet(isPresented: $showAnalysisSheet) {
            if let result = analysisResult {
                TerminalAnalysisSheet(text: result)
            }
        }
    }

    // MARK: - Session Management

    private func addSession() {
        let session = TerminalSession(title: "Terminal \(sessions.count + 1)")
        sessions.append(session)
        activeSessionID = session.id
    }

    private func closeSession(_ id: UUID) {
        guard sessions.count > 1 else { return }
        guard let index = sessions.firstIndex(where: { $0.id == id }) else { return }

        sessions[index].terminate()
        let wasActive = id == activeSessionID
        sessions.remove(at: index)

        if wasActive {
            let newIndex = min(index, sessions.count - 1)
            activeSessionID = sessions[newIndex].id
        }
    }

    // MARK: - AI Analysis

    private func analyzeOutput() {
        guard let session = activeSession else { return }
        let buffer = session.getTextBuffer(lastLines: 50)
        guard !buffer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        isAnalyzing = true

        Task {
            do {
                let analysis = try await ClaudeService.shared.analyzeCLIOutput(buffer)
                await MainActor.run {
                    isAnalyzing = false
                    analysisResult = analysis
                    showAnalysisSheet = true
                }
            } catch {
                await MainActor.run {
                    isAnalyzing = false
                }
            }
        }
    }

}

// MARK: - Analysis Sheet

struct TerminalAnalysisSheet: View {
    let text: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "wand.and.rays")
                    .foregroundStyle(DS.Colors.accent)
                Text("AI Analysis")
                    .font(DS.Font.heading)
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                } label: {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 9))
                        Text("Copy")
                            .font(DS.Font.small)
                    }
                    .foregroundStyle(DS.Colors.textSecondary)
                }
                .buttonStyle(.plainPointer)

                Button("Done") { dismiss() }
                    .font(DS.Font.body)
                    .buttonStyle(.plainPointer)
                    .foregroundStyle(DS.Colors.accent)
            }
            .padding(DS.Spacing.lg)
            .background(DS.Colors.surfaceElevated)

            Divider()

            ScrollView {
                if let attributed = try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
                    Text(attributed)
                        .font(DS.Font.body)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(DS.Spacing.lg)
                } else {
                    Text(text)
                        .font(DS.Font.body)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(DS.Spacing.lg)
                }
            }
        }
        .frame(width: 560, height: 460)
    }
}

// MARK: - Tab Button

private struct TerminalTabButton: View {
    let session: TerminalSession
    let isActive: Bool
    let canClose: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: DS.Spacing.xs) {
                Circle()
                    .fill(session.isRunning ? DS.Colors.success : DS.Colors.danger.opacity(0.5))
                    .frame(width: 6, height: 6)

                Text(displayTitle)
                    .font(DS.Font.caption)
                    .lineLimit(1)

                if canClose && (isActive || isHovered) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(DS.Colors.textTertiary)
                        .frame(width: 16, height: 16)
                        .contentShape(Rectangle())
                        .onTapGesture { onClose() }
                }
            }
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xs)
            .background(
                isActive
                    ? DS.Colors.accentFill
                    : (isHovered ? DS.Colors.fillSecondary : .clear),
                in: RoundedRectangle(cornerRadius: DS.Radius.sm)
            )
            .foregroundStyle(isActive ? DS.Colors.textPrimary : DS.Colors.textSecondary)
        }
        .buttonStyle(.plainPointer)
        .onHover { isHovered = $0 }
        .animation(DS.Animation.quick, value: isHovered)
    }

    private var displayTitle: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if session.currentDirectory == home {
            return session.title
        }
        return (session.currentDirectory as NSString).lastPathComponent
    }
}
