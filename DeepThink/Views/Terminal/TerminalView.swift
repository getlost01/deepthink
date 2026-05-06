import SwiftUI
import SwiftTerm

// MARK: - Split Pane Model

enum SplitDirection {
    case horizontal, vertical
}

@Observable
final class TerminalTab: Identifiable {
    let id = UUID()
    var primarySession: TerminalSession
    var secondarySession: TerminalSession?
    var splitDirection: SplitDirection = .horizontal
    var activeSessionID: UUID

    init(session: TerminalSession) {
        self.primarySession = session
        self.activeSessionID = session.id
    }

    var isSplit: Bool { secondarySession != nil }
    var splitRatio: CGFloat = 0.5

    func split(_ direction: SplitDirection) {
        guard !isSplit else { return }
        splitDirection = direction
        splitRatio = 0.5
        let newSession = TerminalSession(
            title: primarySession.title + " (split)",
            directory: primarySession.currentDirectory
        )
        newSession.onProcessExit = { [weak self] in
            self?.closeSplit()
        }
        secondarySession = newSession
        activeSessionID = newSession.id
    }

    func closeSplit() {
        guard let secondary = secondarySession else { return }
        secondary.terminate()
        secondarySession = nil
        activeSessionID = primarySession.id
    }

    func activeSession() -> TerminalSession {
        if activeSessionID == secondarySession?.id, let s = secondarySession { return s }
        return primarySession
    }

    func terminate() {
        primarySession.terminate()
        secondarySession?.terminate()
    }
}

// MARK: - Main Terminal View

struct DeepThinkTerminalView: View {
    @Environment(AppState.self) private var appState
    private var tabs: [TerminalTab] { appState.terminalTabs }
    private var activeTabID: UUID? {
        get { appState.activeTerminalTabID }
        nonmutating set { appState.activeTerminalTabID = newValue }
    }
    @State private var isAnalyzing = false
    @State private var analysisResult: String?
    @State private var showAnalysisSheet = false
    @State private var showSearch = false
    @State private var searchQuery = ""
    @State private var searchResults: [String] = []

    private var activeTab: TerminalTab? {
        tabs.first { $0.id == activeTabID }
    }

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            Divider()
            searchBar
            terminalContent
        }
        .onAppear {
            if tabs.isEmpty { addTab() }
        }
        .sheet(isPresented: $showAnalysisSheet) {
            if let result = analysisResult {
                TerminalAnalysisSheet(text: result)
            }
        }
        .focusable()
        .focusEffectDisabled()
        .onKeyPress(phases: .down) { press in
            handleKeyPress(press)
        }
    }

    @ViewBuilder
    private var tabBar: some View {
        DSToolbarBar {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Spacing.xxs) {
                    ForEach(tabs) { tab in
                        TerminalTabButton(
                            tab: tab,
                            isActive: tab.id == activeTabID,
                            canClose: tabs.count > 1,
                            onSelect: { activeTabID = tab.id },
                            onClose: { closeTab(tab.id) }
                        )
                    }
                    DSToolbarButton(icon: "plus", color: DS.Colors.textTertiary, size: DS.IconSize.sm) {
                        addTab()
                    }
                }
            }
            Spacer()
            toolbarActions
        }
    }

    @ViewBuilder
    private var searchBar: some View {
        if showSearch {
            TerminalSearchBar(
                query: $searchQuery,
                results: searchResults,
                onSearch: { performSearch() },
                onDismiss: { dismissSearch() }
            )
            Divider()
        }
    }

    @ViewBuilder
    private var terminalContent: some View {
        if let tab = activeTab {
            TerminalPaneView(tab: tab)
        }
    }

    private func handleKeyPress(_ press: KeyPress) -> KeyPress.Result {
        let cmd = press.modifiers.contains(.command)
        let shift = press.modifiers.contains(.shift)
        guard cmd else { return .ignored }

        switch press.characters {
        case "f":
            showSearch.toggle()
            if !showSearch { dismissSearch() }
            return .handled
        case "=", "+":
            activeTab?.activeSession().updateFontSize((activeTab?.activeSession().fontSize ?? 13) + 1)
            return .handled
        case "-":
            activeTab?.activeSession().updateFontSize((activeTab?.activeSession().fontSize ?? 13) - 1)
            return .handled
        case "0":
            activeTab?.activeSession().updateFontSize(13)
            return .handled
        case "d":
            if shift { activeTab?.split(.vertical) } else { activeTab?.split(.horizontal) }
            return .handled
        case "t":
            addTab()
            return .handled
        case "w":
            if let tab = activeTab {
                if tab.isSplit { tab.closeSplit() }
                else if tabs.count > 1 { closeTab(tab.id) }
            }
            return .handled
        default:
            return .ignored
        }
    }

    private func dismissSearch() {
        showSearch = false
        searchQuery = ""
        searchResults = []
    }

    @ViewBuilder
    private var toolbarActions: some View {
        HStack(spacing: DS.Spacing.sm) {
            if let tab = activeTab {
                fontSizeControls(tab: tab)
                Divider().frame(height: 14)
                splitMenuButton(tab: tab)
                Divider().frame(height: 14)
                DSToolbarButton(icon: "magnifyingglass", color: DS.Colors.textTertiary, size: DS.IconSize.sm) {
                    showSearch.toggle()
                }
                .help("Search output (⌘F)")
            }

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

    @ViewBuilder
    private func fontSizeControls(tab: TerminalTab) -> some View {
        let session = tab.activeSession()
        DSToolbarButton(icon: "minus.magnifyingglass", color: DS.Colors.textTertiary, size: DS.IconSize.sm) {
            session.updateFontSize(session.fontSize - 1)
        }
        .help("Decrease font size")

        Text("\(Int(session.fontSize))pt")
            .font(DS.Font.micro)
            .foregroundStyle(DS.Colors.textTertiary)
            .frame(width: 28)

        DSToolbarButton(icon: "plus.magnifyingglass", color: DS.Colors.textTertiary, size: DS.IconSize.sm) {
            session.updateFontSize(session.fontSize + 1)
        }
        .help("Increase font size")
    }

    @ViewBuilder
    private func splitMenuButton(tab: TerminalTab) -> some View {
        if tab.isSplit {
            DSToolbarButton(icon: "xmark.rectangle", color: DS.Colors.textTertiary, size: DS.IconSize.sm) {
                tab.closeSplit()
            }
            .help("Close split")
        } else {
            Menu {
                Button("Split Horizontal") { tab.split(.horizontal) }
                Button("Split Vertical") { tab.split(.vertical) }
            } label: {
                Image(systemName: "rectangle.split.2x1")
                    .font(.system(size: DS.IconSize.sm))
                    .foregroundStyle(DS.Colors.textTertiary)
            }
            .buttonStyle(.plainPointer)
            .pointerOnHover()
            .help("Split pane")
        }
    }

    private func addTab() {
        let session = TerminalSession(title: "Terminal \(appState.terminalTabs.count + 1)")
        let tab = TerminalTab(session: session)
        session.onProcessExit = { [weak appState] in
            guard let appState, appState.terminalTabs.count > 1 else { return }
            guard let index = appState.terminalTabs.firstIndex(where: { $0.id == tab.id }) else { return }
            let wasActive = tab.id == appState.activeTerminalTabID
            appState.terminalTabs.remove(at: index)
            if wasActive && !appState.terminalTabs.isEmpty {
                let newIndex = min(index, appState.terminalTabs.count - 1)
                appState.activeTerminalTabID = appState.terminalTabs[newIndex].id
            }
        }
        appState.terminalTabs.append(tab)
        appState.activeTerminalTabID = tab.id
    }

    private func closeTab(_ id: UUID) {
        guard appState.terminalTabs.count > 1 else { return }
        guard let index = appState.terminalTabs.firstIndex(where: { $0.id == id }) else { return }

        let tab = appState.terminalTabs[index]
        let wasActive = id == activeTabID
        tab.terminate()

        appState.terminalTabs.remove(at: index)

        if wasActive {
            let newIndex = min(index, appState.terminalTabs.count - 1)
            appState.activeTerminalTabID = appState.terminalTabs[newIndex].id
        }
    }

    private func analyzeOutput() {
        guard let tab = activeTab else { return }
        let buffer = tab.activeSession().getTextBuffer(lastLines: 50)
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

    private func performSearch() {
        guard let tab = activeTab, !searchQuery.isEmpty else {
            searchResults = []
            return
        }
        let text = tab.activeSession().getAllText()
        let query = searchQuery.lowercased()
        searchResults = text.components(separatedBy: "\n").filter {
            $0.lowercased().contains(query)
        }
    }
}

// MARK: - Split Pane Content

private struct TerminalPaneView: View {
    let tab: TerminalTab
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        if let secondary = tab.secondarySession {
            GeometryReader { geo in
                let isH = tab.splitDirection == .horizontal
                let total = isH ? geo.size.width : geo.size.height
                let firstSize = total * tab.splitRatio
                let secondSize = total - firstSize - 4

                if isH {
                    HStack(spacing: 0) {
                        pane(session: tab.primarySession) { tab.activeSessionID = tab.primarySession.id }
                            .frame(width: max(60, firstSize))
                        splitHandle(isHorizontal: true, total: total)
                        pane(session: secondary) { tab.activeSessionID = secondary.id }
                            .frame(width: max(60, secondSize))
                    }
                } else {
                    VStack(spacing: 0) {
                        pane(session: tab.primarySession) { tab.activeSessionID = tab.primarySession.id }
                            .frame(height: max(40, firstSize))
                        splitHandle(isHorizontal: false, total: total)
                        pane(session: secondary) { tab.activeSessionID = secondary.id }
                            .frame(height: max(40, secondSize))
                    }
                }
            }
        } else {
            pane(session: tab.primarySession) { tab.activeSessionID = tab.primarySession.id }
        }
    }

    @ViewBuilder
    private func pane(session: TerminalSession, onTap: @escaping () -> Void) -> some View {
        TerminalHostView(session: session)
            .id(session.id)
            .padding(DS.Spacing.sm)
            .background(DS.Colors.terminal)
            .contentShape(Rectangle())
            .onTapGesture { onTap() }
    }

    private func splitHandle(isHorizontal: Bool, total: CGFloat) -> some View {
        Rectangle()
            .fill(DS.Colors.border)
            .frame(width: isHorizontal ? 4 : nil, height: isHorizontal ? nil : 4)
            .contentShape(Rectangle())
            .onHover { hovering in
                if hovering {
                    if isHorizontal {
                        NSCursor.resizeLeftRight.push()
                    } else {
                        NSCursor.resizeUpDown.push()
                    }
                } else {
                    NSCursor.pop()
                }
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let delta = isHorizontal ? value.translation.width : value.translation.height
                        let newRatio = tab.splitRatio + (delta - dragOffset) / total
                        tab.splitRatio = min(0.8, max(0.2, newRatio))
                        dragOffset = delta
                    }
                    .onEnded { _ in
                        dragOffset = 0
                    }
            )
    }
}

// MARK: - Search Bar

private struct TerminalSearchBar: View {
    @Binding var query: String
    let results: [String]
    let onSearch: () -> Void
    let onDismiss: () -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: DS.IconSize.sm))
                .foregroundStyle(DS.Colors.textTertiary)

            TextField("Search terminal output...", text: $query)
                .font(DS.Font.caption)
                .textFieldStyle(.plain)
                .focused($isFocused)
                .onSubmit { onSearch() }

            if !results.isEmpty {
                Text("\(results.count) match\(results.count == 1 ? "" : "es")")
                    .font(DS.Font.micro)
                    .foregroundStyle(DS.Colors.textTertiary)
            }

            Button { onDismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: DS.IconSize.xs, weight: .bold))
                    .foregroundStyle(DS.Colors.textTertiary)
            }
            .buttonStyle(.plainPointer)
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.xs + 2)
        .background(DS.Colors.surfaceElevated)
        .onAppear { isFocused = true }
        .onKeyPress(.escape) {
            onDismiss()
            return .handled
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
                            .font(.system(size: DS.IconSize.xs))
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

// MARK: - Tab Button with Rename

private struct TerminalTabButton: View {
    let tab: TerminalTab
    let isActive: Bool
    let canClose: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    @State private var isHovered = false
    @State private var isEditing = false
    @State private var editTitle = ""

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: DS.Spacing.xs) {
                Circle()
                    .fill(tab.primarySession.isRunning ? DS.Colors.success : DS.Colors.danger.opacity(0.5))
                    .frame(width: 6, height: 6)

                if isEditing {
                    TextField("", text: $editTitle)
                        .font(DS.Font.caption)
                        .textFieldStyle(.plain)
                        .frame(width: 80)
                        .onSubmit { commitRename() }
                        .onKeyPress(.escape) {
                            isEditing = false
                            return .handled
                        }
                } else {
                    Text(displayTitle)
                        .font(DS.Font.caption)
                        .lineLimit(1)
                }

                if tab.isSplit {
                    Image(systemName: "rectangle.split.2x1")
                        .font(.system(size: DS.IconSize.xs))
                        .foregroundStyle(DS.Colors.textTertiary)
                }

                if canClose {
                    Button { onClose() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: DS.IconSize.xs, weight: .bold))
                            .foregroundStyle(DS.Colors.textTertiary)
                            .frame(width: 16, height: 16)
                    }
                    .buttonStyle(.plainPointer)
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
        .onTapGesture(count: 2) {
            editTitle = tab.primarySession.title
            isEditing = true
        }
    }

    private func commitRename() {
        let trimmed = editTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            tab.primarySession.title = trimmed
        }
        isEditing = false
    }

    private var displayTitle: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let session = tab.primarySession
        if session.currentDirectory == home {
            return session.title
        }
        return (session.currentDirectory as NSString).lastPathComponent
    }
}
