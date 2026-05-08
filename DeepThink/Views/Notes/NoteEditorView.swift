import SwiftData
import SwiftUI

struct NoteEditorView: View {
    @Bindable var note: Note
    @FocusState private var titleFocused: Bool
    @State private var saveTask: Task<Void, Never>?
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Query(filter: #Predicate<Project> { !$0.isArchived }) private var projects: [Project]
    @Query(filter: #Predicate<Note> { !$0.isArchived }) private var allNotes: [Note]
    @Query(filter: #Predicate<TaskItem> { !$0.isArchived }) private var allTasks: [TaskItem]
    @Query private var allReminders: [Reminder]
    @State private var deadLinkTask: Task<Void, Never>?
    @State private var showSkillMenu = false
    @State private var linkPickerType: String?
    @State private var linkInsertRequest: DeepLinkInsertRequest?
    @State private var hasDeadLinks = false
    @State private var deadLinkUUIDs: Set<String> = []
    @State private var cleanDeadLinksRequest: UUID?
    @State private var showBacklinks = false
    @State private var cachedLinkPreviews: [String: [String: String]] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if note.isArchived {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "archivebox.fill")
                        .font(.system(size: DS.IconSize.xs, weight: .medium))
                    Text("Archived — unarchive to edit")
                        .font(DS.Font.caption)
                        .fontWeight(.medium)
                    Spacer()
                    Button("Unarchive") {
                        note.isArchived = false
                        note.modifiedAt = Date()
                    }
                    .font(DS.Font.caption)
                    .buttonStyle(.plainPointer)
                    .foregroundStyle(DS.Colors.accent)
                }
                .foregroundStyle(DS.Colors.textSecondary)
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.vertical, DS.Spacing.sm)
                .background(DS.Colors.fillSecondary)
                .overlay(Divider(), alignment: .bottom)
            }

            HStack(spacing: DS.Spacing.md) {
                TextField("Give your note a title...", text: $note.title)
                    .textFieldStyle(.plain)
                    .font(DS.Font.title)
                    .focused($titleFocused)
                    .disabled(note.isArchived)

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
                    .padding(.horizontal, DS.Spacing.sm2)
                    .padding(.vertical, DS.Spacing.xs2)
                    .background(DS.Colors.fill, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.sm)
                            .strokeBorder(DS.Colors.border, lineWidth: 1)
                    )
                }
                .buttonStyle(.plainPointer)
                .fixedSize()
                .disabled(note.isArchived)

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
                    .padding(.horizontal, DS.Spacing.sm2)
                    .padding(.vertical, DS.Spacing.xs2)
                    .background(DS.Colors.fill, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.sm)
                            .strokeBorder(DS.Colors.border, lineWidth: 1)
                    )
                }
                .buttonStyle(.plainPointer)
                .fixedSize()
                .disabled(note.isArchived)
                .help("Run AI skill on this note")
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.vertical, DS.Spacing.md)

            Divider()

            if hasDeadLinks {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: DS.IconSize.xs))
                        .foregroundStyle(DS.Colors.warning)
                    Text("This note contains broken links to deleted items")
                        .font(DS.Font.small)
                        .foregroundStyle(DS.Colors.textSecondary)
                    Spacer()
                    Button("Fix") {
                        cleanDeadLinksRequest = UUID()
                    }
                    .font(DS.Font.small)
                    .foregroundStyle(DS.Colors.warning)
                    .buttonStyle(.plainPointer)
                }
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.vertical, DS.Spacing.xs)
                .frame(maxWidth: .infinity)
                .background(DS.Colors.warning.opacity(0.08))
            }

            let backlinks = BacklinkService.shared.backlinks(for: note.id, context: modelContext)
                .compactMap { link in allNotes.first { $0.id == link.sourceNoteID } }
                .filter { $0.id != note.id }

            RichMarkdownEditor(
                text: $note.content,
                isReadOnly: note.isArchived,
                onLinkClick: { url in appState.handleDeepLink(url) },
                onRequestLinkInsert: { type in linkPickerType = type },
                onWikiLinkClick: { title in
                    guard !title.isEmpty,
                          let target = allNotes.first(where: { $0.title.lowercased() == title.lowercased() }) else { return }
                    appState.navigateToNote(target.id)
                },
                linkInsertRequest: linkInsertRequest,
                wikiLinks: Dictionary(allNotes.filter { !$0.title.isEmpty }.map { ($0.title, $0.id.uuidString) }, uniquingKeysWith: { first, _ in first }),
                linkPreviews: cachedLinkPreviews,
                deadLinkUUIDs: deadLinkUUIDs,
                onRequestDeadLinkClean: { hasDeadLinks = false; deadLinkUUIDs = [] },
                cleanDeadLinksRequest: cleanDeadLinksRequest
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .sheet(isPresented: Binding(get: { linkPickerType != nil }, set: { if !$0 { linkPickerType = nil } })) {
                if let type = linkPickerType {
                    DeepLinkPickerSheet(type: type, onSelect: { title, url in
                        linkInsertRequest = DeepLinkInsertRequest(text: title, url: url)
                        linkPickerType = nil
                    }, onDismiss: { linkPickerType = nil })
                }
            }

            if !backlinks.isEmpty {
                Divider()
                BacklinksPanel(backlinks: backlinks, isExpanded: $showBacklinks, onNavigate: { appState.navigateToNote($0) })
            }
        }
        .clipped()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onChange(of: note.content) {
            debouncedSave()
            scheduleScanDeadLinks()
        }
        .onChange(of: note.title) { debouncedSave() }
        .onAppear {
            if note.title.isEmpty { titleFocused = true }
            publishNoteContext()
            scheduleScanDeadLinks()
            buildLinkPreviews()
        }
        .onChange(of: allNotes.count) { buildLinkPreviews() }
        .onChange(of: allTasks.count) { buildLinkPreviews() }
        .onChange(of: allReminders.count) { buildLinkPreviews() }
        .onDisappear {
            appState.currentNoteContent = nil
            appState.currentNoteTitle = nil
            appState.currentNoteTags = []
        }
        .onChange(of: note.id) {
            publishNoteContext()
            deadLinkUUIDs = []
            hasDeadLinks = false
            cachedLinkPreviews = [:]
        }
    }

    private func scheduleScanDeadLinks() {
        deadLinkTask?.cancel()
        let content = note.content
        let tasks = allTasks, notes = allNotes, reminders = allReminders
        deadLinkTask = Task {
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            let dead = DeadLinkScanner.deadLinkUUIDs(in: content, tasks: tasks, notes: notes, reminders: reminders)
            await MainActor.run {
                deadLinkUUIDs = dead
                hasDeadLinks = !dead.isEmpty
            }
        }
    }

    private func debouncedSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            note.modifiedAt = Date()
            scheduleKnowledgeExtraction()
            BacklinkService.shared.updateLinks(for: note, allNotes: allNotes, context: modelContext)
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

    private func buildLinkPreviews() {
        var map: [String: [String: String]] = [:]
        for n in allNotes {
            map["deepthink://note/\(n.id.uuidString)"] = [
                "title": n.title.isEmpty ? "Untitled" : n.title,
                "subtitle": n.modifiedAt.relativeFormatted,
                "snippet": String(n.content.prefix(120))
            ]
        }
        for t in allTasks {
            map["deepthink://task/\(t.id.uuidString)"] = [
                "title": t.title.isEmpty ? "Untitled" : t.title,
                "subtitle": t.status.rawValue,
                "snippet": String(t.detail.prefix(120))
            ]
        }
        for r in allReminders {
            map["deepthink://reminder/\(r.id.uuidString)"] = [
                "title": r.title.isEmpty ? "Untitled" : r.title,
                "subtitle": r.reminderDate.map(\.shortFormatted) ?? "",
                "snippet": String(r.notes.prefix(120))
            ]
        }
        cachedLinkPreviews = map
    }

    private func publishNoteContext() {
        appState.currentNoteContent = note.content
        appState.currentNoteTitle = note.title
        appState.currentNoteTags = note.tags.map(\.name)
    }
}

private struct BacklinksPanel: View {
    let backlinks: [Note]
    @Binding var isExpanded: Bool
    let onNavigate: (UUID) -> Void
    @State private var isHeaderHovered = false

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(DS.Animation.quick) { isExpanded.toggle() }
            } label: {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "arrow.backward")
                        .font(.system(size: DS.IconSize.xs))
                        .foregroundStyle(DS.Colors.textTertiary)
                    Text("^[\(backlinks.count) backlink](inflect: true)")
                        .font(DS.Font.small)
                        .foregroundStyle(DS.Colors.textTertiary)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: DS.IconSize.xs))
                        .foregroundStyle(DS.Colors.textTertiary)
                }
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.vertical, DS.Spacing.sm)
                .background(isHeaderHovered ? DS.Colors.fill : .clear)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plainPointer)
            .onHover { isHeaderHovered = $0 }
            .animation(DS.Animation.quick, value: isHeaderHovered)

            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(backlinks) { source in
                        Button {
                            onNavigate(source.id)
                        } label: {
                            HStack(spacing: DS.Spacing.sm) {
                                Image(systemName: "doc.text")
                                    .font(.system(size: DS.IconSize.xs))
                                    .foregroundStyle(DS.Colors.accent)
                                Text(source.title.isEmpty ? "Untitled" : source.title)
                                    .font(DS.Font.small)
                                    .foregroundStyle(DS.Colors.textPrimary)
                                    .lineLimit(1)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: DS.IconSize.xs))
                                    .foregroundStyle(DS.Colors.textTertiary)
                            }
                            .padding(.horizontal, DS.Spacing.xl)
                            .padding(.vertical, DS.Spacing.sm)
                        }
                        .buttonStyle(.plainPointer)
                    }
                }
                .padding(.bottom, DS.Spacing.sm)
            }
        }
    }
}
