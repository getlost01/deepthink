import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct KnowledgeBrowserView: View {
    @Environment(AppState.self) private var appState
    @State private var searchText = ""
    @State private var bucketFilter: String?
    @State private var selectedEntry: KnowledgeEntry?
    @State private var showURLSheet = false
    @State private var showNewEntry = false
    @State private var showScriptSheet = false
    @State private var showDeleteConfirm = false
    @State private var showNewBucket = false
    @State private var newBucketName = ""
    @State private var showObsidianImport = false
    @State private var displayedCount = 20

    private let pageSize = 20
    private var knowledge: KnowledgeService {
        KnowledgeService.shared
    }

    private var filteredEntries: [KnowledgeEntry] {
        var results = knowledge.entries
        if let filter = bucketFilter {
            results = results.filter { $0.bucket == filter }
        }
        if !searchText.isEmpty {
            results = knowledge.search(searchText)
            if let filter = bucketFilter {
                results = results.filter { $0.bucket == filter }
            }
        }
        return results
    }

    var body: some View {
        ResizableSplitView(minLeftWidth: 300, minRightWidth: 400) {
            VStack(spacing: 0) {
                // Search + Add
                HStack(spacing: DS.Spacing.sm) {
                    DSSearchField(text: $searchText, placeholder: "Search knowledge...")

                    Menu {
                        Section("Capture") {
                            Button { showURLSheet = true } label: {
                                Label("Scrape URL", systemImage: "globe")
                            }
                            Button { captureClipboard() } label: {
                                Label("From Clipboard", systemImage: "doc.on.clipboard")
                            }
                            Button { showScriptSheet = true } label: {
                                Label("Run Script", systemImage: "terminal")
                            }
                        }
                        Section("Import") {
                            Button { importFiles() } label: {
                                Label("Import Files", systemImage: "doc.badge.plus")
                            }
                            Button { importFolder() } label: {
                                Label("Import Folder", systemImage: "folder.badge.plus")
                            }
                            Button { showObsidianImport = true } label: {
                                Label("Import Obsidian Vault", systemImage: "square.stack.3d.up")
                            }
                        }
                        Section {
                            Button { showNewEntry = true } label: {
                                Label("Write New", systemImage: "pencil")
                            }
                            Button { showNewBucket = true } label: {
                                Label("New Bucket", systemImage: "cylinder.split.1x2")
                            }
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: DS.IconSize.sm, weight: .medium))
                            .foregroundStyle(DS.Colors.textSecondary)
                            .frame(width: 28, height: 28)
                            .background(DS.Colors.fill, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                            .overlay(
                                RoundedRectangle(cornerRadius: DS.Radius.sm)
                                    .strokeBorder(DS.Colors.border, lineWidth: 1)
                            )
                            .contentShape(Rectangle())
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .onHover { hovering in
                        if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.sm)

                HStack(spacing: DS.Spacing.xs) {
                    Picker(selection: $bucketFilter) {
                        Text("All Buckets").tag(nil as String?)
                        ForEach(knowledge.buckets, id: \.self) { bucket in
                            Label(bucket, systemImage: "cylinder.split.1x2").tag(bucket as String?)
                        }
                    } label: { EmptyView() }
                        .pickerStyle(.menu)
                        .font(DS.Font.caption)
                        .fixedSize()

                    if bucketFilter != nil {
                        Button {
                            bucketFilter = nil
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: DS.IconSize.xs, weight: .semibold))
                                .foregroundStyle(DS.Colors.textSecondary)
                                .frame(width: DS.IconSize.xl, height: DS.IconSize.xl)
                                .background(DS.Colors.fill, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                                .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm).strokeBorder(DS.Colors.border, lineWidth: 1))
                        }
                        .buttonStyle(.plainPointer)
                    }

                    Spacer()
                    Text("\(filteredEntries.count) entries")
                        .font(DS.Font.small)
                        .foregroundStyle(DS.Colors.textTertiary)
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.sm)

                Divider()

                if filteredEntries.isEmpty {
                    DSEmptyState(
                        icon: "brain",
                        title: knowledge.entries.isEmpty ? "Start Building Your Knowledge" : "No Matches",
                        subtitle: knowledge.entries
                            .isEmpty ?
                            "Save articles, paste text, import files, or write things down. Everything here becomes context that AI can use to give you better answers." :
                            "Try a different search term or clear the filter.",
                        hint: knowledge.entries.isEmpty ? "Try saving a web article you want to reference later" : nil,
                        action: knowledge.entries.isEmpty ? { showURLSheet = true } : nil,
                        actionTitle: "Save a Web Page"
                    )
                } else {
                    let visibleEntries = Array(filteredEntries.prefix(displayedCount))
                    let hasMore = filteredEntries.count > displayedCount
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(visibleEntries) { entry in
                                EntryRow(entry: entry, isSelected: selectedEntry?.id == entry.id, bucketFiltered: bucketFilter != nil) {
                                    selectedEntry = entry
                                }
                                .contextMenu {
                                    Menu {
                                        ForEach(knowledge.buckets, id: \.self) { bucket in
                                            Button {
                                                KnowledgeService.shared.moveEntry(entry, to: bucket)
                                            } label: {
                                                Label(bucket, systemImage: "folder")
                                            }
                                            .disabled(entry.bucket == bucket)
                                        }
                                    } label: {
                                        Label("Move to Bucket", systemImage: "folder.badge.arrow.up")
                                    }
                                    Divider()
                                    Button(role: .destructive) {
                                        selectedEntry = entry
                                        showDeleteConfirm = true
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                if entry.id != visibleEntries.last?.id || hasMore {
                                    Divider()
                                }
                            }
                            if hasMore {
                                HStack(spacing: DS.Spacing.xs) {
                                    ProgressView().controlSize(.small)
                                    Text("Loading more…")
                                        .font(DS.Font.small)
                                        .foregroundStyle(DS.Colors.textTertiary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, DS.Spacing.md)
                                .onAppear { displayedCount += pageSize }
                            }
                        }
                    }
                }
            }
        } right: {
            if let entry = selectedEntry {
                KnowledgeDetailView(entry: entry) {
                    showDeleteConfirm = true
                }
            } else {
                DSEmptyState(
                    icon: "doc.text.magnifyingglass",
                    title: "Select an Entry",
                    subtitle: "Pick something from your knowledge base to read, tag, or edit."
                )
            }
        }
        .onChange(of: searchText) { displayedCount = pageSize }
        .onChange(of: bucketFilter) { displayedCount = pageSize }
        .onAppear {
            knowledge.reload()
            if let entryID = appState.selectedKnowledgeEntryID {
                selectedEntry = knowledge.entries.first { $0.id == entryID }
                appState.selectedKnowledgeEntryID = nil
            }
        }
        .onChange(of: appState.selectedKnowledgeEntryID) { _, newID in
            if let entryID = newID {
                selectedEntry = knowledge.entries.first { $0.id == entryID }
                appState.selectedKnowledgeEntryID = nil
            }
        }
        .sheet(isPresented: $showURLSheet) { URLScrapeSheet() }
        .sheet(isPresented: $showNewEntry) { NewKnowledgeSheet() }
        .sheet(isPresented: $showScriptSheet) { ScriptRunSheet() }
        .confirmationDialog("Delete Entry?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                if let entry = selectedEntry {
                    let title = entry.title
                    KnowledgeService.shared.deleteEntry(entry)
                    selectedEntry = nil
                    ToastState.shared.show("\(title) deleted", icon: "trash", color: DS.Colors.danger)
                }
            }
        } message: {
            Text("This will permanently delete \"\(selectedEntry?.title ?? "")\" from your knowledge base.")
        }
        .sheet(isPresented: $showObsidianImport) {
            ObsidianImportView()
        }
        .sheet(isPresented: $showNewBucket) {
            NewBucketSheet(bucketName: $newBucketName, isPresented: $showNewBucket) { name in
                KnowledgeService.shared.createBucket(named: name)
                bucketFilter = name
                newBucketName = ""
            }
        }
    }

    private func captureClipboard() {
        let ok = DataCollectorService.shared.captureClipboard()
        knowledge.reload()
        if ok { ToastState.shared.show("Clipboard saved to knowledge") } else { ToastState.shared.showError("Clipboard is empty or unsupported") }
    }

    private func importFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.allowedContentTypes = [UTType(filenameExtension: "md")!, .plainText]
        panel.begin { response in
            guard response == .OK else { return }
            var count = 0
            for url in panel.urls {
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                    count += DataCollectorService.shared.importFolder(at: url.path)
                } else {
                    if DataCollectorService.shared.importFile(at: url) { count += 1 }
                }
            }
            knowledge.reload()
            ToastState.shared.show("\(count) file\(count == 1 ? "" : "s") imported to knowledge")
        }
    }

    private func importFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.message = "Select a folder to import markdown files from"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            let count = DataCollectorService.shared.importFolder(at: url.path)
            knowledge.reload()
            ToastState.shared.show("\(count) file\(count == 1 ? "" : "s") imported to knowledge")
        }
    }
}

// MARK: - Entry Row

private struct EntryRow: View {
    let entry: KnowledgeEntry
    let isSelected: Bool
    let bucketFiltered: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: DS.Spacing.md) {
                DSIconBadge(
                    icon: entry.sourceIcon,
                    color: isSelected ? DS.Colors.accent : DS.Colors.textSecondary,
                    background: isSelected ? DS.Colors.accentFill : DS.Colors.fillSecondary
                )
                .padding(.top, 1)

                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    HStack {
                        Text(entry.title)
                            .font(DS.Font.body)
                            .fontWeight(.medium)
                            .foregroundStyle(DS.Colors.textPrimary)
                            .lineLimit(1)
                            .help(entry.title)
                        Spacer()
                        Text(entry.importedAt.relativeFormatted)
                            .font(DS.Font.small)
                            .foregroundStyle(DS.Colors.textTertiary)
                    }

                    HStack(spacing: DS.Spacing.xs) {
                        if !bucketFiltered {
                            Text(entry.bucket)
                                .font(DS.Font.small)
                                .foregroundStyle(DS.Colors.textTertiary)
                            Text("·")
                                .font(DS.Font.small)
                                .foregroundStyle(DS.Colors.textTertiary)
                        }
                        Text(entry.source)
                            .font(DS.Font.small)
                            .foregroundStyle(DS.Colors.textTertiary)
                        if !entry.tags.isEmpty {
                            Text("·")
                                .font(DS.Font.small)
                                .foregroundStyle(DS.Colors.textTertiary)
                            Text(entry.tags.prefix(2).joined(separator: ", "))
                                .font(DS.Font.small)
                                .foregroundStyle(DS.Colors.textTertiary)
                                .lineLimit(1)
                        }
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md + 2)
            .background(isSelected ? DS.Colors.accentFill : (isHovered ? DS.Colors.fillSecondary : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plainPointer)
        .onHover { isHovered = $0 }
        .animation(DS.Animation.quick, value: isHovered)
    }
}

private struct BucketPill: View {
    let label: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.xs) {
                Text(label)
                    .font(DS.Font.small)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundStyle(isSelected ? DS.Colors.accent : DS.Colors.textSecondary)
                Text("\(count)")
                    .font(DS.Font.micro)
                    .fontWeight(.medium)
                    .foregroundStyle(isSelected ? DS.Colors.accent.opacity(0.7) : DS.Colors.textTertiary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(isSelected ? DS.Colors.accent.opacity(0.12) : DS.Colors.fillSecondary, in: Capsule())
            }
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xs)
            .background(
                isSelected ? DS.Colors.accentFill : (isHovered ? DS.Colors.fill : .clear),
                in: Capsule()
            )
            .overlay(Capsule().strokeBorder(isSelected ? DS.Colors.accent.opacity(0.3) : DS.Colors.border, lineWidth: 1))
        }
        .buttonStyle(.plainPointer)
        .onHover { isHovered = $0 }
        .animation(DS.Animation.quick, value: isHovered)
    }
}

// MARK: - Detail View

struct KnowledgeDetailView: View {
    let entry: KnowledgeEntry
    let onDelete: () -> Void
    @Environment(AppState.self) private var appState
    @Query private var allNotes: [Note]
    @State private var isAutoTagging = false
    @State private var editableContent: String
    @State private var editableTitle: String
    @State private var isEditingTitle = false
    @State private var hasLoaded = false
    @State private var activeEntry: KnowledgeEntry

    private var liveTags: [String] {
        KnowledgeService.shared.entries.first(where: { $0.id == entry.id })?.tags ?? entry.tags
    }

    init(entry: KnowledgeEntry, onDelete: @escaping () -> Void) {
        self.entry = entry
        self.onDelete = onDelete
        _editableContent = State(initialValue: entry.content)
        _editableTitle = State(initialValue: entry.title)
        _activeEntry = State(initialValue: entry)
    }

    @State private var showCopied = false
    @State private var showLinkedPopover = false

    private var linkedNotes: [Note] {
        BacklinkService.shared.notesLinkedTo(entry: entry, notes: allNotes)
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                TextField("Entry title", text: $editableTitle)
                    .textFieldStyle(.plain)
                    .font(DS.Font.heading)
                    .foregroundStyle(DS.Colors.textPrimary)
                    .onSubmit { commitTitleEdit() }
                    .onChange(of: editableTitle) { _, _ in isEditingTitle = true }

                HStack(spacing: DS.Spacing.sm) {
                    Text(entry.source)
                    Text("·")
                    Text(entry.formattedSize)
                    Text("·")
                    Text(entry.importedAt.formatted(date: .abbreviated, time: .shortened))
                }
                .font(DS.Font.small)
                .foregroundStyle(DS.Colors.textTertiary)

                HStack(spacing: DS.Spacing.md) {
                    BucketPickerButton(currentBucket: entry.bucket) { newBucket in
                        KnowledgeService.shared.moveEntry(entry, to: newBucket)
                    }

                    Button {
                        autoTagEntry()
                    } label: {
                        HStack(spacing: DS.Spacing.xs) {
                            if isAutoTagging {
                                ProgressView().controlSize(.mini)
                                    .foregroundStyle(DS.Colors.textSecondary)
                            } else {
                                Image(systemName: "sparkles")
                                    .font(.system(size: DS.IconSize.sm))
                                    .foregroundStyle(DS.Colors.accent)
                            }
                            Text(isAutoTagging ? "Generating..." : "Generate Tags")
                                .font(DS.Font.caption)
                                .foregroundStyle(DS.Colors.textSecondary)
                        }
                        .padding(.horizontal, DS.Spacing.sm + 2)
                        .padding(.vertical, DS.Spacing.xs + 2)
                        .background(DS.Colors.fillSecondary, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                    }
                    .buttonStyle(.plainPointer)
                    .disabled(isAutoTagging)

                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(editableContent, forType: .string)
                        withAnimation(DS.Animation.quick) { showCopied = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation(DS.Animation.quick) { showCopied = false }
                        }
                    } label: {
                        HStack(spacing: DS.Spacing.xs) {
                            Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                                .font(.system(size: DS.IconSize.sm))
                            Text(showCopied ? "Copied!" : "Copy")
                                .font(DS.Font.caption)
                        }
                        .foregroundStyle(showCopied ? DS.Colors.success : DS.Colors.textSecondary)
                        .padding(.horizontal, DS.Spacing.sm + 2)
                        .padding(.vertical, DS.Spacing.xs + 2)
                        .background(DS.Colors.fill, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                    }
                    .buttonStyle(.plainPointer)

                    if let url = entry.sourceURL {
                        Button {
                            if let u = URL(string: url) { NSWorkspace.shared.open(u) }
                        } label: {
                            HStack(spacing: DS.Spacing.xs) {
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: DS.IconSize.sm))
                                Text("Open Source")
                                    .font(DS.Font.caption)
                            }
                            .foregroundStyle(DS.Colors.textSecondary)
                            .padding(.horizontal, DS.Spacing.sm + 2)
                            .padding(.vertical, DS.Spacing.xs + 2)
                            .background(DS.Colors.fill, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                        }
                        .buttonStyle(.plainPointer)
                    }

                    if !linkedNotes.isEmpty {
                        Button {
                            if linkedNotes.count == 1 {
                                appState.navigateToNote(linkedNotes[0].id)
                            } else {
                                showLinkedPopover = true
                            }
                        } label: {
                            HStack(spacing: DS.Spacing.xs) {
                                Image(systemName: "link")
                                    .font(.system(size: DS.IconSize.xs))
                                Text("\(linkedNotes.count) linked")
                                    .font(DS.Font.small)
                            }
                            .foregroundStyle(DS.Colors.accent)
                            .padding(.horizontal, DS.Spacing.sm)
                            .padding(.vertical, DS.Spacing.xs + 2)
                            .background(DS.Colors.accentFill, in: Capsule())
                        }
                        .buttonStyle(.plainPointer)
                        .popover(isPresented: $showLinkedPopover, arrowEdge: .bottom) {
                            VStack(alignment: .leading, spacing: 0) {
                                Text("Linked Notes")
                                    .font(DS.Font.caption)
                                    .foregroundStyle(DS.Colors.textSecondary)
                                    .padding(.horizontal, DS.Spacing.md)
                                    .padding(.vertical, DS.Spacing.sm)
                                Divider()
                                ForEach(linkedNotes) { note in
                                    Button {
                                        showLinkedPopover = false
                                        appState.navigateToNote(note.id)
                                    } label: {
                                        Text(note.title.isEmpty ? "Untitled" : note.title)
                                            .font(DS.Font.body)
                                            .foregroundStyle(DS.Colors.textPrimary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.horizontal, DS.Spacing.md)
                                            .padding(.vertical, DS.Spacing.sm)
                                    }
                                    .buttonStyle(.plainPointer)
                                }
                            }
                            .frame(minWidth: 220)
                        }
                    }

                    Spacer()

                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        HStack(spacing: DS.Spacing.xs) {
                            Image(systemName: "trash")
                                .font(.system(size: DS.IconSize.sm))
                            Text("Delete")
                                .font(DS.Font.caption)
                        }
                        .foregroundStyle(DS.Colors.danger)
                        .padding(.horizontal, DS.Spacing.sm + 2)
                        .padding(.vertical, DS.Spacing.xs + 2)
                        .background(DS.Colors.fill, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                    }
                    .buttonStyle(.plainPointer)
                }
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .background(DS.Colors.surfaceElevated)

            Divider()

            if !liveTags.isEmpty {
                HStack(spacing: DS.Spacing.xs) {
                    Text("Tags:")
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Colors.textTertiary)
                    ForEach(liveTags, id: \.self) { tag in
                        DSPill(text: tag)
                    }
                    Spacer()
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.sm)

                Divider()
            }

            MarkdownEditorWithToggle(
                text: $editableContent,
                placeholder: "Write knowledge entry content...",
                onSave: { commitTitleEdit(); saveEntry() }
            )
            .id(activeEntry.id)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            activeEntry = entry
            editableContent = entry.content
            editableTitle = entry.title
            hasLoaded = true
        }
        .onChange(of: entry.id) { _, _ in
            commitTitleEdit()
            saveEntry()
            activeEntry = entry
            editableContent = entry.content
            editableTitle = entry.title
            isEditingTitle = false
            showCopied = false
        }
        .onDisappear { commitTitleEdit(); saveEntry() }
    }

    private func saveEntry() {
        let filePath = activeEntry.filePath
        guard hasLoaded, editableContent != activeEntry.content,
              FileManager.default.fileExists(atPath: filePath.path) else { return }
        let (frontmatter, _) = KnowledgeService.shared.parseFrontmatter(
            (try? String(contentsOf: filePath, encoding: .utf8)) ?? ""
        )
        var md = "---\n"
        for (key, value) in frontmatter {
            md += "\(key): \(value)\n"
        }
        md += "---\n\n\(editableContent)"
        try? md.write(to: filePath, atomically: true, encoding: .utf8)
        KnowledgeService.shared.reload()
        if let fresh = KnowledgeService.shared.entries.first(where: { $0.id == activeEntry.id }) {
            activeEntry = fresh
        }
    }

    private func commitTitleEdit() {
        guard isEditingTitle else { return }
        isEditingTitle = false
        let trimmed = editableTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != activeEntry.title else {
            editableTitle = activeEntry.title
            return
        }
        KnowledgeService.shared.renameEntry(activeEntry, title: trimmed)
        if let fresh = KnowledgeService.shared.entries.first(where: { $0.id == activeEntry.id }) {
            activeEntry = fresh
        }
    }

    private func autoTagEntry() {
        isAutoTagging = true
        Task {
            await KnowledgeExtractionService.shared.autoTagAndUpdate(entry: entry)
            await MainActor.run { isAutoTagging = false }
        }
    }
}

// MARK: - Bucket Picker Button

private struct BucketPickerButton: View {
    let currentBucket: String
    let onMove: (String) -> Void

    var body: some View {
        Menu {
            ForEach(KnowledgeService.shared.buckets, id: \.self) { bucket in
                Button(bucket) { onMove(bucket) }
                    .disabled(bucket == currentBucket)
            }
        } label: {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "cylinder.split.1x2")
                    .font(.system(size: DS.IconSize.sm))
                    .foregroundStyle(DS.Colors.textSecondary)
                Text(currentBucket)
            }
            .font(DS.Font.caption)
            .padding(.horizontal, DS.Spacing.sm + 2)
            .padding(.vertical, DS.Spacing.xs + 2)
            .background(DS.Colors.fillSecondary, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
        }
        .buttonStyle(.plainPointer)
    }
}

// MARK: - URL Scrape Sheet

struct URLScrapeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var urlText = ""
    @State private var titleText = ""
    @State private var isScraping = false
    @State private var result: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Scrape URL")
                    .font(DS.Font.heading)
                Spacer()
                Button("Close") { dismiss() }
                    .font(DS.Font.body)
                    .buttonStyle(.plainPointer)
                    .foregroundStyle(DS.Colors.textSecondary)
            }
            .padding(DS.Spacing.lg)
            .background(DS.Colors.surfaceElevated)

            Divider()

            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                DSLabeledTextField(label: "URL", text: $urlText, placeholder: "https://example.com/docs")
                DSLabeledTextField(label: "Title (optional)", text: $titleText, placeholder: "Auto-detected from page")

                if let result {
                    HStack(spacing: DS.Spacing.sm) {
                        Image(systemName: result.hasPrefix("Error") ? "xmark.circle.fill" : "checkmark.circle.fill")
                            .foregroundStyle(result.hasPrefix("Error") ? DS.Colors.danger : DS.Colors.success)
                        Text(result)
                            .font(DS.Font.caption)
                    }
                }

                Button {
                    Task { await scrape() }
                } label: {
                    HStack(spacing: DS.Spacing.sm) {
                        if isScraping {
                            ProgressView().controlSize(.small).tint(DS.Colors.onAccent)
                        }
                        Text(isScraping ? "Scraping..." : "Scrape & Save")
                            .font(DS.Font.body).fontWeight(.semibold)
                    }
                    .foregroundStyle(DS.Colors.onAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.md)
                    .background(
                        urlText.isEmpty ? DS.Colors.accent.opacity(DS.Opacity.disabled) : DS.Colors.accent,
                        in: RoundedRectangle(cornerRadius: DS.Radius.md)
                    )
                }
                .buttonStyle(.plainPointer)
                .disabled(urlText.isEmpty || isScraping)
            }
            .padding(DS.Spacing.lg)
        }
        .frame(width: 450)
        .fixedSize(horizontal: false, vertical: true)
    }

    @MainActor
    private func scrape() async {
        isScraping = true
        let success = await DataCollectorService.shared.scrapeURL(urlText, title: titleText.isEmpty ? nil : titleText)
        result = success ? "Saved to knowledge base" : "Error: Failed to scrape URL"
        isScraping = false
        if success {
            KnowledgeService.shared.reload()
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            dismiss()
        }
    }
}

// MARK: - New Knowledge Sheet

struct NewKnowledgeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var content = ""
    @State private var tags = ""
    @State private var selectedBucket = "General"

    private var knowledge: KnowledgeService {
        KnowledgeService.shared
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("New Knowledge Entry")
                    .font(DS.Font.heading)
                Spacer()
                Button("Cancel") { dismiss() }
                    .font(DS.Font.body)
                    .buttonStyle(.plainPointer)
                    .foregroundStyle(DS.Colors.textSecondary)
                    .padding(.trailing, DS.Spacing.sm)
                Button(action: save) {
                    Text("Save")
                        .font(DS.Font.body).fontWeight(.semibold)
                        .foregroundStyle(DS.Colors.onAccent)
                        .padding(.horizontal, DS.Spacing.lg)
                        .padding(.vertical, DS.Spacing.sm)
                        .background(
                            title.isEmpty ? DS.Colors.accent.opacity(DS.Opacity.disabled) : DS.Colors.accent,
                            in: RoundedRectangle(cornerRadius: DS.Radius.sm)
                        )
                }
                .buttonStyle(.plainPointer)
                .disabled(title.isEmpty)
            }
            .padding(DS.Spacing.lg)
            .background(DS.Colors.surfaceElevated)

            Divider()

            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    Text("TITLE")
                        .font(DS.Font.small)
                        .foregroundStyle(DS.Colors.textTertiary)
                        .textCase(.uppercase)

                    TextField("Enter a title...", text: $title)
                        .textFieldStyle(.plain)
                        .font(DS.Font.body)
                        .padding(.horizontal, DS.Spacing.lg)
                        .padding(.vertical, DS.Spacing.md)
                        .background(DS.Colors.fillSecondary, in: RoundedRectangle(cornerRadius: DS.Radius.md))
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.md)
                                .strokeBorder(DS.Colors.border, lineWidth: 1)
                        )
                }

                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    Text("CONTENT")
                        .font(DS.Font.small)
                        .foregroundStyle(DS.Colors.textTertiary)
                        .textCase(.uppercase)

                    MarkdownEditorWithToggle(text: $content, placeholder: "Start writing...")
                        .frame(maxHeight: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.md)
                                .strokeBorder(DS.Colors.border, lineWidth: 1)
                        )
                }

                HStack(spacing: DS.Spacing.sm) {
                    Menu {
                        ForEach(knowledge.buckets, id: \.self) { bucket in
                            Button {
                                selectedBucket = bucket
                            } label: {
                                Label(bucket, systemImage: "archivebox")
                            }
                        }
                    } label: {
                        HStack(spacing: DS.Spacing.xs) {
                            Image(systemName: "archivebox")
                                .font(.system(size: DS.IconSize.sm))
                                .foregroundStyle(DS.Colors.textSecondary)
                            Text(selectedBucket)
                        }
                        .font(DS.Font.caption)
                        .padding(.horizontal, DS.Spacing.sm + 2)
                        .padding(.vertical, DS.Spacing.xs + 2)
                        .background(DS.Colors.fillSecondary, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                    }
                    .buttonStyle(.plainPointer)

                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "tag")
                            .font(.system(size: DS.IconSize.sm))
                            .foregroundStyle(DS.Colors.textTertiary)
                        TextField("Tags (comma separated)", text: $tags)
                            .textFieldStyle(.plain)
                            .font(DS.Font.caption)
                    }
                    .padding(.horizontal, DS.Spacing.sm + 2)
                    .padding(.vertical, DS.Spacing.xs + 2)
                    .background(DS.Colors.fillSecondary, in: RoundedRectangle(cornerRadius: DS.Radius.sm))

                    Spacer()
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.lg)
        }
        .frame(width: 600, height: 520)
    }

    private func save() {
        let tagList = tags.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        KnowledgeService.shared.createEntry(title: title, content: content, source: "manual", tags: tagList, bucket: selectedBucket)
        dismiss()
    }
}

// MARK: - Script Run Sheet

struct ScriptRunSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var command = ""
    @State private var isRunning = false
    @State private var result: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Run Script")
                    .font(DS.Font.heading)
                Spacer()
                Button("Close") { dismiss() }
                    .font(DS.Font.body)
                    .buttonStyle(.plainPointer)
                    .foregroundStyle(DS.Colors.textSecondary)
            }
            .padding(DS.Spacing.lg)
            .background(DS.Colors.surfaceElevated)

            Divider()

            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                DSLabeledTextField(label: "Shell Command", text: $command, placeholder: "curl -s https://api.example.com | jq .")

                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "info.circle").font(.system(size: DS.IconSize.xs))
                    Text("Output is saved as a knowledge entry. Use any command that prints text.")
                        .font(DS.Font.caption)
                }
                .foregroundStyle(DS.Colors.textTertiary)

                if let result {
                    HStack(spacing: DS.Spacing.sm) {
                        Image(systemName: result.hasPrefix("Error") ? "xmark.circle.fill" : "checkmark.circle.fill")
                            .foregroundStyle(result.hasPrefix("Error") ? DS.Colors.danger : DS.Colors.success)
                        Text(result)
                            .font(DS.Font.caption)
                    }
                }

                Button {
                    Task { await run() }
                } label: {
                    HStack(spacing: DS.Spacing.sm) {
                        if isRunning { ProgressView().controlSize(.small).tint(DS.Colors.onAccent) }
                        Text(isRunning ? "Running..." : "Run & Save")
                            .font(DS.Font.body).fontWeight(.semibold)
                    }
                    .foregroundStyle(DS.Colors.onAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.md)
                    .background(
                        command.isEmpty ? DS.Colors.accent.opacity(DS.Opacity.disabled) : DS.Colors.accent,
                        in: RoundedRectangle(cornerRadius: DS.Radius.md)
                    )
                }
                .buttonStyle(.plainPointer)
                .disabled(command.isEmpty || isRunning)
            }
            .padding(DS.Spacing.lg)
        }
        .frame(width: 480)
        .fixedSize(horizontal: false, vertical: true)
    }

    @MainActor
    private func run() async {
        isRunning = true
        let success = await DataCollectorService.shared.runScript(command: command)
        result = success ? "Saved to knowledge base" : "Error: Script produced no output"
        isRunning = false
        if success {
            KnowledgeService.shared.reload()
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            dismiss()
        }
    }
}

// MARK: - New Bucket Sheet

private struct NewBucketSheet: View {
    @Binding var bucketName: String
    @Binding var isPresented: Bool
    let onCreate: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("New Bucket")
                    .font(DS.Font.heading)
                Spacer()
                Button("Cancel") { isPresented = false; bucketName = "" }
                    .font(DS.Font.body)
                    .buttonStyle(.plainPointer)
                    .foregroundStyle(DS.Colors.textSecondary)
            }
            .padding(DS.Spacing.lg)
            .background(DS.Colors.surfaceElevated)

            Divider()

            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                DSLabeledTextField(label: "Bucket Name", text: $bucketName, placeholder: "e.g. Research, APIs, Notes")

                Button {
                    let name = bucketName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !name.isEmpty else { return }
                    onCreate(name)
                    isPresented = false
                } label: {
                    Text("Create Bucket")
                        .font(DS.Font.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(DS.Colors.onAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.md)
                        .background(
                            bucketName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? DS.Colors.accent.opacity(DS.Opacity.disabled)
                                : DS.Colors.accent,
                            in: RoundedRectangle(cornerRadius: DS.Radius.md)
                        )
                }
                .buttonStyle(.plainPointer)
                .disabled(bucketName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(DS.Spacing.lg)
        }
        .frame(width: 380)
        .fixedSize(horizontal: false, vertical: true)
    }
}
