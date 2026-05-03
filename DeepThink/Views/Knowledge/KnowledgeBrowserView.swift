import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct KnowledgeBrowserView: View {
    @Environment(AppState.self) private var appState
    @State private var searchText = ""
    @State private var folderFilter: String?
    @State private var selectedEntry: KnowledgeEntry?
    @State private var showURLSheet = false
    @State private var showNewEntry = false
    @State private var showScriptSheet = false
    @State private var showDeleteConfirm = false
    @State private var showNewFolder = false
    @State private var newFolderName = ""
    @State private var newFolderIcon = "folder"

    private var knowledge: KnowledgeService { KnowledgeService.shared }

    private var filteredEntries: [KnowledgeEntry] {
        var results = knowledge.entries
        if let filter = folderFilter {
            results = results.filter { $0.folder == filter }
        }
        if !searchText.isEmpty {
            results = knowledge.search(searchText)
            if let filter = folderFilter {
                results = results.filter { $0.folder == filter }
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
                        }
                        Section {
                            Button { showNewEntry = true } label: {
                                Label("Write New", systemImage: "pencil")
                            }
                            Button { showNewFolder = true } label: {
                                Label("New Folder", systemImage: "folder.badge.plus")
                            }
                        }
                    } label: {
                        HStack(spacing: DS.Spacing.xs) {
                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .semibold))
                            Text("Add")
                                .font(DS.Font.small)
                                .fontWeight(.medium)
                        }
                        .foregroundStyle(DS.Colors.onAccent)
                        .padding(.horizontal, DS.Spacing.md)
                        .padding(.vertical, DS.Spacing.sm)
                        .background(DS.Colors.accent, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.md)

                HStack(spacing: DS.Spacing.sm) {
                    Picker(selection: $folderFilter) {
                        Text("All Folders").tag(nil as String?)
                        ForEach(knowledge.folders, id: \.self) { folder in
                            Label(folder, systemImage: "folder").tag(folder as String?)
                        }
                    } label: { EmptyView() }
                    .pickerStyle(.menu)
                    .font(DS.Font.caption)
                    .fixedSize()

                    Text("\(filteredEntries.count) entries")
                        .font(DS.Font.small)
                        .foregroundStyle(DS.Colors.textTertiary)

                    Spacer()
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.sm)

                Divider()

                if filteredEntries.isEmpty {
                    DSEmptyState(
                        icon: "brain",
                        title: knowledge.entries.isEmpty ? "Start Building Your Knowledge" : "No Matches",
                        subtitle: knowledge.entries.isEmpty ? "Save articles, paste text, import files, or write things down. Everything here becomes context that AI can use to give you better answers." : "Try a different search term or clear the filter.",
                        hint: knowledge.entries.isEmpty ? "Try saving a web article you want to reference later" : nil,
                        action: knowledge.entries.isEmpty ? { showURLSheet = true } : nil,
                        actionTitle: "Save a Web Page"
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredEntries) { entry in
                                EntryRow(entry: entry, isSelected: selectedEntry?.id == entry.id) {
                                    selectedEntry = entry
                                }
                                .contextMenu {
                                    Menu("Move to Folder") {
                                        ForEach(knowledge.folders, id: \.self) { folder in
                                            Button(folder) {
                                                KnowledgeService.shared.moveEntry(entry, to: folder)
                                            }
                                            .disabled(entry.folder == folder)
                                        }
                                    }
                                    Divider()
                                    Button("Delete", role: .destructive) {
                                        selectedEntry = entry
                                        showDeleteConfirm = true
                                    }
                                }
                                if entry.id != filteredEntries.last?.id {
                                    Divider()
                                }
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
                    KnowledgeService.shared.deleteEntry(entry)
                    selectedEntry = nil
                }
            }
        } message: {
            Text("This will permanently delete \"\(selectedEntry?.title ?? "")\" from your knowledge base.")
        }
        .sheet(isPresented: $showNewFolder) {
            NewFolderSheet(
                folderName: $newFolderName,
                folderIcon: $newFolderIcon,
                isPresented: $showNewFolder
            ) { name, icon in
                KnowledgeService.shared.createFolder(named: name)
                folderFilter = name
                newFolderName = ""
                newFolderIcon = "folder"
            }
        }
    }

    private func captureClipboard() {
        _ = DataCollectorService.shared.captureClipboard()
        knowledge.reload()
    }

    private func importFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.allowedContentTypes = [UTType(filenameExtension: "md")!, .plainText]
        panel.begin { response in
            guard response == .OK else { return }
            for url in panel.urls {
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                    _ = DataCollectorService.shared.importFolder(at: url.path)
                } else {
                    _ = DataCollectorService.shared.importFile(at: url)
                }
            }
            knowledge.reload()
        }
    }

    private func importFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.message = "Select a folder to import markdown files from"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            _ = DataCollectorService.shared.importFolder(at: url.path)
            knowledge.reload()
        }
    }
}

// MARK: - Entry Row

private struct EntryRow: View {
    let entry: KnowledgeEntry
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.md) {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(entry.title)
                        .font(DS.Font.body)
                        .fontWeight(.medium)
                        .foregroundStyle(DS.Colors.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: DS.Spacing.sm) {
                        Text(entry.folder)
                            .font(DS.Font.small)
                            .foregroundStyle(DS.Colors.textSecondary)

                        Text("·")
                            .foregroundStyle(DS.Colors.textTertiary)

                        Text(entry.source)
                            .font(DS.Font.small)
                            .foregroundStyle(DS.Colors.textTertiary)
                    }
                }

                Spacer()

                Text(entry.importedAt.relativeFormatted)
                    .font(DS.Font.small)
                    .foregroundStyle(DS.Colors.textTertiary)

                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(DS.Colors.textTertiary)
                    .opacity(isHovered ? 1 : 0)
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)
            .background(isSelected ? DS.Colors.accentFill : (isHovered ? DS.Colors.fillSecondary : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plainPointer)
        .onHover { hovering in
            isHovered = hovering
            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
        .animation(DS.Animation.quick, value: isHovered)
    }
}

// MARK: - Detail View

struct KnowledgeDetailView: View {
    let entry: KnowledgeEntry
    let onDelete: () -> Void
    @Query private var allNotes: [Note]
    @State private var isAutoTagging = false
    @State private var editableContent: String = ""
    @State private var hasLoaded = false
    @State private var showCopied = false

    private var linkedNotes: [Note] {
        BacklinkService.shared.notesLinkedTo(entry: entry, notes: allNotes)
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                Text(entry.title)
                    .font(DS.Font.heading)
                    .foregroundStyle(DS.Colors.textPrimary)

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
                    Button {
                        autoTagEntry()
                    } label: {
                        HStack(spacing: DS.Spacing.xs) {
                            if isAutoTagging {
                                ProgressView().controlSize(.mini)
                            } else {
                                Image(systemName: "sparkles")
                                    .font(.system(size: DS.IconSize.sm))
                            }
                            Text(isAutoTagging ? "Generating..." : "Generate Tags")
                                .font(DS.Font.caption)
                        }
                        .foregroundStyle(DS.Colors.accent)
                        .padding(.horizontal, DS.Spacing.sm + 2)
                        .padding(.vertical, DS.Spacing.xs + 2)
                        .background(DS.Colors.accentFill, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
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
                        HStack(spacing: DS.Spacing.xs) {
                            Image(systemName: "link")
                                .font(.system(size: 9))
                            Text("\(linkedNotes.count) linked")
                                .font(DS.Font.small)
                        }
                        .foregroundStyle(DS.Colors.accent)
                        .padding(.horizontal, DS.Spacing.sm)
                        .padding(.vertical, DS.Spacing.xs + 2)
                        .background(DS.Colors.accentFill, in: Capsule())
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

            if !entry.tags.isEmpty {
                HStack(spacing: DS.Spacing.xs) {
                    ForEach(entry.tags, id: \.self) { tag in
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
                onSave: { saveEntry() },
                autoSaveInterval: 3
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { editableContent = entry.content; hasLoaded = true }
        .onChange(of: entry.id) { editableContent = entry.content; showCopied = false }
    }

    private func saveEntry() {
        guard hasLoaded else { return }
        let (frontmatter, _) = KnowledgeService.shared.parseFrontmatter(
            (try? String(contentsOf: entry.filePath, encoding: .utf8)) ?? ""
        )
        var md = "---\n"
        for (key, value) in frontmatter { md += "\(key): \(value)\n" }
        md += "---\n\n\(editableContent)"
        try? md.write(to: entry.filePath, atomically: true, encoding: .utf8)
    }

    private func autoTagEntry() {
        isAutoTagging = true
        Task {
            await KnowledgeExtractionService.shared.autoTagAndUpdate(entry: entry)
            await MainActor.run { isAutoTagging = false }
        }
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
                    .background(urlText.isEmpty ? DS.Colors.accent.opacity(DS.Opacity.disabled) : DS.Colors.accent, in: RoundedRectangle(cornerRadius: DS.Radius.md))
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
                        .background(title.isEmpty ? DS.Colors.accent.opacity(DS.Opacity.disabled) : DS.Colors.accent, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                }
                .buttonStyle(.plainPointer)
                .disabled(title.isEmpty)
            }
            .padding(DS.Spacing.lg)
            .background(DS.Colors.surfaceElevated)

            Divider()

            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                DSLabeledTextField(label: "Title", text: $title, placeholder: "Entry title")
                DSLabeledTextField(label: "Tags (comma-separated)", text: $tags, placeholder: "api, docs, reference")
                DSLabeledTextEditor(label: "Content", text: $content, minHeight: 200)
            }
            .padding(DS.Spacing.lg)
        }
        .frame(width: 550)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func save() {
        let tagList = tags.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        KnowledgeService.shared.createEntry(title: title, content: content, source: "manual", tags: tagList)
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
                    Image(systemName: "info.circle").font(.system(size: 10))
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
                    .background(command.isEmpty ? DS.Colors.accent.opacity(DS.Opacity.disabled) : DS.Colors.accent, in: RoundedRectangle(cornerRadius: DS.Radius.md))
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

// MARK: - New Folder Sheet

private struct NewFolderSheet: View {
    @Binding var folderName: String
    @Binding var folderIcon: String
    @Binding var isPresented: Bool
    let onCreate: (String, String) -> Void

    private let iconOptions = [
        "folder", "folder.fill", "book.closed", "doc.text",
        "star", "heart", "bookmark", "lightbulb",
        "globe", "link", "tag", "archivebox",
        "cpu", "hammer", "wrench", "paintbrush",
        "graduationcap", "briefcase", "building.2", "person.2"
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("New Folder")
                    .font(DS.Font.heading)
                Spacer()
                Button("Cancel") { isPresented = false; folderName = "" }
                    .font(DS.Font.body)
                    .buttonStyle(.plainPointer)
                    .foregroundStyle(DS.Colors.textSecondary)
            }
            .padding(DS.Spacing.lg)
            .background(DS.Colors.surfaceElevated)

            Divider()

            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                DSLabeledTextField(label: "Folder Name", text: $folderName, placeholder: "e.g. Research, APIs, Notes")

                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    Text("Icon")
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Colors.textSecondary)

                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(40), spacing: DS.Spacing.sm), count: 8), spacing: DS.Spacing.sm) {
                        ForEach(iconOptions, id: \.self) { icon in
                            Button {
                                folderIcon = icon
                            } label: {
                                Image(systemName: icon)
                                    .font(.system(size: 14))
                                    .foregroundStyle(folderIcon == icon ? DS.Colors.accent : DS.Colors.textSecondary)
                                    .frame(width: 36, height: 36)
                                    .background(
                                        folderIcon == icon ? DS.Colors.accentFill : DS.Colors.fill,
                                        in: RoundedRectangle(cornerRadius: DS.Radius.sm)
                                    )
                            }
                            .buttonStyle(.plainPointer)
                        }
                    }
                }

                Button {
                    let name = folderName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !name.isEmpty else { return }
                    onCreate(name, folderIcon)
                    isPresented = false
                } label: {
                    Text("Create Folder")
                        .font(DS.Font.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(DS.Colors.onAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.md)
                        .background(
                            folderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? DS.Colors.accent.opacity(DS.Opacity.disabled)
                                : DS.Colors.accent,
                            in: RoundedRectangle(cornerRadius: DS.Radius.md)
                        )
                }
                .buttonStyle(.plainPointer)
                .disabled(folderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(DS.Spacing.lg)
        }
        .frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)
    }
}
