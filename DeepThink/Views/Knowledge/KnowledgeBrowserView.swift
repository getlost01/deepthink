import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct KnowledgeBrowserView: View {
    @State private var searchText = ""
    @State private var sourceFilter: String?
    @State private var selectedEntry: KnowledgeEntry?
    @State private var showURLSheet = false
    @State private var showNewEntry = false
    @State private var showScriptSheet = false
    @State private var showDeleteConfirm = false

    private var knowledge: KnowledgeService { KnowledgeService.shared }

    private var filteredEntries: [KnowledgeEntry] {
        var results = knowledge.entries
        if let filter = sourceFilter {
            results = results.filter { $0.source == filter }
        }
        if !searchText.isEmpty {
            results = knowledge.search(searchText)
            if let filter = sourceFilter {
                results = results.filter { $0.source == filter }
            }
        }
        return results
    }

    private let sources = ["url", "folder", "clipboard", "manual", "script", "mcp"]

    var body: some View {
        ResizableSplitView(minLeftWidth: 300, minRightWidth: 400) {
            VStack(spacing: 0) {
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
                        }
                    } label: {
                        HStack(spacing: DS.Spacing.xs) {
                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .semibold))
                            Text("Add")
                                .font(DS.Font.small)
                                .fontWeight(.medium)
                        }
                        .foregroundStyle(.white)
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
                    Picker("Source", selection: $sourceFilter) {
                        Text("All Sources").tag(nil as String?)
                        ForEach(sources, id: \.self) { source in
                            Label(source.capitalized, systemImage: iconFor(source)).tag(source as String?)
                        }
                    }
                    .pickerStyle(.menu)
                    .font(DS.Font.caption)

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
                        subtitle: knowledge.entries.isEmpty ? "Scrape web pages, paste from clipboard, import files, or write entries manually. Everything you add here becomes searchable context for AI chat." : "Try a different search term or clear the filter.",
                        action: knowledge.entries.isEmpty ? { showURLSheet = true } : nil,
                        actionTitle: "Scrape a URL"
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredEntries) { entry in
                                EntryRow(entry: entry, isSelected: selectedEntry?.id == entry.id) {
                                    selectedEntry = entry
                                }
                                if entry.id != filteredEntries.last?.id {
                                    Divider().padding(.leading, 48)
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
                    subtitle: "Pick a knowledge entry from the list to view, tag, or find linked notes. Entries are automatically available as context in AI chat."
                )
            }
        }
        .onAppear { knowledge.reload() }
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

    private func iconFor(_ source: String) -> String {
        switch source {
        case "url": return "globe"
        case "folder": return "folder"
        case "clipboard": return "doc.on.clipboard"
        case "manual": return "pencil"
        case "script": return "terminal"
        case "mcp": return "puzzlepiece.extension"
        default: return "doc.text"
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
                ZStack {
                    RoundedRectangle(cornerRadius: DS.Radius.sm)
                        .fill(isSelected ? DS.Colors.accentFill : DS.Colors.fill)
                        .frame(width: 30, height: 30)
                    Image(systemName: entry.sourceIcon)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(isSelected ? DS.Colors.accent : DS.Colors.textTertiary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.title)
                        .font(DS.Font.body)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .foregroundStyle(DS.Colors.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: DS.Spacing.sm) {
                        Text(entry.source)
                            .font(DS.Font.small)
                            .foregroundStyle(DS.Colors.textTertiary)

                        if !entry.tags.isEmpty {
                            Text(entry.tags.prefix(2).joined(separator: ", "))
                                .font(DS.Font.small)
                                .foregroundStyle(DS.Colors.textTertiary)
                        }
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(entry.importedAt, style: .relative)
                        .font(DS.Font.small)
                        .foregroundStyle(DS.Colors.textTertiary)
                    Text(entry.formattedSize)
                        .font(DS.Font.small)
                        .foregroundStyle(DS.Colors.textTertiary)
                }
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm + 2)
            .background(isSelected ? DS.Colors.accentFill : (isHovered ? DS.Colors.fillSecondary : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plainPointer)
        .onHover { isHovered = $0 }
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

    private var linkedNotes: [Note] {
        BacklinkService.shared.notesLinkedTo(entry: entry, notes: allNotes)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: entry.sourceIcon)
                    .font(.system(size: DS.IconSize.md))
                    .foregroundStyle(DS.Colors.accent)

                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.title)
                        .font(DS.Font.heading)
                    HStack(spacing: DS.Spacing.sm) {
                        Text(entry.source)
                            .font(DS.Font.small)
                            .foregroundStyle(DS.Colors.textTertiary)
                        Text(entry.formattedSize)
                            .font(DS.Font.small)
                            .foregroundStyle(DS.Colors.textTertiary)
                        Text(entry.importedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(DS.Font.small)
                            .foregroundStyle(DS.Colors.textTertiary)
                    }
                }

                Spacer()

                if !linkedNotes.isEmpty {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "link")
                            .font(.system(size: 9))
                        Text("\(linkedNotes.count) linked")
                            .font(DS.Font.small)
                    }
                    .foregroundStyle(DS.Colors.accent)
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, 3)
                    .background(DS.Colors.accentFill, in: Capsule())
                    .help(linkedNotes.map(\.title).joined(separator: ", "))
                }

                Button {
                    autoTagEntry()
                } label: {
                    HStack(spacing: DS.Spacing.xs) {
                        if isAutoTagging {
                            ProgressView().controlSize(.mini)
                        } else {
                            Image(systemName: "tag")
                                .font(.system(size: 9))
                        }
                        Text("Auto-Tag")
                            .font(DS.Font.small)
                    }
                    .foregroundStyle(DS.Colors.accent)
                }
                .buttonStyle(.plainPointer)
                .disabled(isAutoTagging)

                if let url = entry.sourceURL {
                    DSToolbarButton(icon: "link", size: DS.IconSize.sm) {
                        if let u = URL(string: url) { NSWorkspace.shared.open(u) }
                    }
                }

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(editableContent, forType: .string)
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

                DSToolbarButton(icon: "trash", color: DS.Colors.danger, size: DS.IconSize.sm) {
                    onDelete()
                }
            }
            .padding(DS.Spacing.lg)
            .background(.bar)

            Divider()

            if !entry.tags.isEmpty {
                HStack(spacing: DS.Spacing.xs) {
                    ForEach(entry.tags, id: \.self) { tag in
                        DSPill(text: tag)
                    }
                    Spacer()
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.sm)

                Divider()
            }

            MarkdownEditorWithToggle(
                text: $editableContent,
                placeholder: "Write knowledge entry content...",
                onSave: { saveEntry() },
                autoSaveInterval: 10
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { editableContent = entry.content; hasLoaded = true }
        .onChange(of: entry.id) { editableContent = entry.content }
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
            .background(.bar)

            Divider()

            VStack(spacing: DS.Spacing.xl) {
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
                            ProgressView().controlSize(.small).tint(.white)
                        }
                        Text(isScraping ? "Scraping..." : "Scrape & Save")
                            .font(DS.Font.body).fontWeight(.semibold)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.md)
                    .background(urlText.isEmpty ? DS.Colors.accent.opacity(0.5) : DS.Colors.accent, in: RoundedRectangle(cornerRadius: DS.Radius.md))
                }
                .buttonStyle(.plainPointer)
                .disabled(urlText.isEmpty || isScraping)
            }
            .padding(DS.Spacing.xl)
        }
        .frame(width: 450, height: 320)
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
                Button(action: save) {
                    Text("Save")
                        .font(DS.Font.body).fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, DS.Spacing.lg)
                        .padding(.vertical, DS.Spacing.sm)
                        .background(title.isEmpty ? DS.Colors.accent.opacity(0.5) : DS.Colors.accent, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                }
                .buttonStyle(.plainPointer)
                .disabled(title.isEmpty)
            }
            .padding(DS.Spacing.lg)
            .background(.bar)

            Divider()

            VStack(spacing: DS.Spacing.lg) {
                DSLabeledTextField(label: "Title", text: $title, placeholder: "Entry title")
                DSLabeledTextField(label: "Tags (comma-separated)", text: $tags, placeholder: "api, docs, reference")
                DSLabeledTextEditor(label: "Content", text: $content, minHeight: 200)
            }
            .padding(DS.Spacing.xl)
        }
        .frame(width: 550, height: 500)
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
            .background(.bar)

            Divider()

            VStack(spacing: DS.Spacing.xl) {
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
                        if isRunning { ProgressView().controlSize(.small).tint(.white) }
                        Text(isRunning ? "Running..." : "Run & Save")
                            .font(DS.Font.body).fontWeight(.semibold)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.md)
                    .background(command.isEmpty ? DS.Colors.accent.opacity(0.5) : DS.Colors.accent, in: RoundedRectangle(cornerRadius: DS.Radius.md))
                }
                .buttonStyle(.plainPointer)
                .disabled(command.isEmpty || isRunning)
            }
            .padding(DS.Spacing.xl)
        }
        .frame(width: 480, height: 320)
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
