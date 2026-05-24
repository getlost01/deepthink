import SwiftTerm
import SwiftUI

// MARK: - Split Pane Model

enum SplitDirection {
    case horizontal
    case vertical
}

@Observable
final class TerminalTab: Identifiable {
    let id = UUID()
    var primarySession: TerminalSession
    var secondarySession: TerminalSession?
    var splitDirection: SplitDirection = .horizontal
    var activeSessionID: UUID

    init(session: TerminalSession) {
        primarySession = session
        activeSessionID = session.id
    }

    var isSplit: Bool {
        secondarySession != nil
    }

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
    private var tabs: [TerminalTab] {
        appState.terminalTabs
    }

    private var activeTabID: UUID? {
        get { appState.activeTerminalTabID }
        nonmutating set { appState.activeTerminalTabID = newValue }
    }

    @State private var isAnalyzing = false
    @State private var analysisResult: String?
    @State private var showAnalysisSheet = false
    @State private var showAnalysisError = false
    @State private var analysisError: String?
    @State private var showSearch = false
    @State private var searchQuery = ""
    @State private var searchResultCount: Int = 0

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
        .alert("Analysis Failed", isPresented: $showAnalysisError, presenting: analysisError) { _ in
            Button("OK") { showAnalysisError = false }
        } message: { err in
            Text(err)
        }
        .overlay(alignment: .topLeading) { terminalKeyboardShortcuts }
    }

    /// Hidden zero-size buttons that register keyboard shortcuts at the app-menu level,
    /// so they fire even when the SwiftTerm NSView holds first responder.
    private var terminalKeyboardShortcuts: some View {
        ZStack {
            Button("") { addTab() }
                .keyboardShortcut("t", modifiers: .command)
            Button("") { handleCloseShortcut() }
                .keyboardShortcut("w", modifiers: .command)
            Button("") { toggleSearch() }
                .keyboardShortcut("f", modifiers: .command)
            Button("") { changeFontSize(by: 1) }
                .keyboardShortcut("=", modifiers: .command)
            Button("") { changeFontSize(by: -1) }
                .keyboardShortcut("-", modifiers: .command)
            Button("") { resetFontSize() }
                .keyboardShortcut("0", modifiers: .command)
        }
        .frame(width: 0, height: 0)
        .clipped()
        .allowsHitTesting(false)
    }

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
                resultCount: searchResultCount,
                onSearch: { performSearch() },
                onPrevious: { performSearchPrevious() },
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

    // MARK: - Toolbar

    private var toolbarActions: some View {
        HStack(spacing: DS.Spacing.sm) {
            if let tab = activeTab {
                fontSizeControls(tab: tab)
                Divider().frame(height: 14)
                splitMenuButton(tab: tab)
                Divider().frame(height: 14)
                DSToolbarButton(icon: "magnifyingglass", color: DS.Colors.textTertiary, size: DS.IconSize.sm) {
                    toggleSearch()
                }
                .help("Search output")
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

    // MARK: - Actions

    private func handleCloseShortcut() {
        if let tab = activeTab {
            if tab.isSplit { tab.closeSplit() } else if tabs.count > 1 { closeTab(tab.id) }
        }
    }

    private func toggleSearch() {
        showSearch.toggle()
        if !showSearch { dismissSearch() }
    }

    private func changeFontSize(by delta: CGFloat) {
        guard let session = activeTab?.activeSession() else { return }
        session.updateFontSize(session.fontSize + delta)
    }

    private func resetFontSize() {
        activeTab?.activeSession().updateFontSize(13)
    }

    private func dismissSearch() {
        showSearch = false
        searchQuery = ""
        searchResultCount = 0
        activeTab?.activeSession().terminalView?.clearSearch()
    }

    private func addTab() {
        appState.terminalTabCounter += 1
        let session = TerminalSession(title: "Terminal \(appState.terminalTabCounter)")
        let tab = TerminalTab(session: session)
        // Capture tab weakly to avoid the retain cycle:
        // tab → primarySession → onProcessExit closure → tab (strong) → cycle.
        session.onProcessExit = { [weak appState, weak tab] in
            guard let appState, let tab, appState.terminalTabs.count > 1 else { return }
            guard let index = appState.terminalTabs.firstIndex(where: { $0.id == tab.id }) else { return }
            let wasActive = tab.id == appState.activeTerminalTabID
            appState.terminalTabs.remove(at: index)
            if wasActive, !appState.terminalTabs.isEmpty {
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
                    analysisError = error.localizedDescription
                    showAnalysisError = true
                }
            }
        }
    }

    /// Counts matches and navigates to the first one via SwiftTerm's built-in search,
    /// which properly highlights results and scrolls the terminal to the match.
    private func performSearch() {
        guard let tab = activeTab, !searchQuery.isEmpty else {
            searchResultCount = 0
            return
        }
        let text = tab.activeSession().getAllText()
        let q = searchQuery.lowercased()
        searchResultCount = text.lowercased().components(separatedBy: q).count - 1
        tab.activeSession().terminalView?.findNext(searchQuery)
    }

    private func performSearchPrevious() {
        guard let tab = activeTab, !searchQuery.isEmpty else { return }
        tab.activeSession().terminalView?.findPrevious(searchQuery)
    }
}

// MARK: - Split Pane Content

private struct TerminalPaneView: View {
    let tab: TerminalTab
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false

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
                    if isHorizontal { NSCursor.resizeLeftRight.push() } else { NSCursor.resizeUpDown.push() }
                } else if !isDragging {
                    // Only pop cursor on hover-exit when not mid-drag.
                    // During a fast drag the cursor can leave the 4pt handle
                    // area; popping here would reset the cursor mid-gesture.
                    NSCursor.pop()
                }
            }
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        if !isDragging { isDragging = true }
                        let delta = isHorizontal ? value.translation.width : value.translation.height
                        let newRatio = tab.splitRatio + (delta - dragOffset) / total
                        tab.splitRatio = min(0.8, max(0.2, newRatio))
                        dragOffset = delta
                    }
                    .onEnded { _ in
                        dragOffset = 0
                        isDragging = false
                        NSCursor.pop()
                    }
            )
    }
}

// MARK: - Search Bar

private struct TerminalSearchBar: View {
    @Binding var query: String
    var resultCount: Int
    let onSearch: () -> Void
    let onPrevious: () -> Void
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

            if !query.isEmpty {
                Group {
                    if resultCount > 0 {
                        Text("\(resultCount) match\(resultCount == 1 ? "" : "es")")
                    } else {
                        Text("No results")
                    }
                }
                .font(DS.Font.micro)
                .foregroundStyle(DS.Colors.textTertiary)

                Button { onPrevious() } label: {
                    Image(systemName: "chevron.up")
                        .font(.system(size: DS.IconSize.xs, weight: .semibold))
                        .foregroundStyle(DS.Colors.textSecondary)
                }
                .buttonStyle(.plainPointer)
                .help("Previous match (⇧↵)")

                Button { onSearch() } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: DS.IconSize.xs, weight: .semibold))
                        .foregroundStyle(DS.Colors.textSecondary)
                }
                .buttonStyle(.plainPointer)
                .help("Next match (↵)")
            }

            Button { onDismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: DS.IconSize.xs, weight: .bold))
                    .foregroundStyle(DS.Colors.textTertiary)
                    .frame(width: 16, height: 16)
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
        // simultaneousGesture lets the Button handle single-tap (select) while
        // TapGesture(count:2) handles double-tap (rename) independently.
        .simultaneousGesture(
            TapGesture(count: 2).onEnded {
                editTitle = tab.primarySession.title
                isEditing = true
            }
        )
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
