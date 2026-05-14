import SwiftData
import SwiftUI

struct TaskDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Bindable var task: TaskItem
    @Query private var projects: [Project]
    @Query(filter: #Predicate<Note> { !$0.isArchived }) private var allNotes: [Note]
    @Query(filter: #Predicate<TaskItem> { !$0.isArchived }) private var allTasksForScan: [TaskItem]
    @Query private var allReminders: [Reminder]
    @State private var showCustomPoints = false
    @State private var customPointsText = ""
    @State private var showCalendar = false
    @State private var newSubtaskTitle = ""
    @State private var linkPickerType: String?
    @State private var linkInsertRequest: DeepLinkInsertRequest?
    @State private var showSubtasks = true
    @State private var hasDeadLinks = false
    @State private var deadLinkUUIDs: Set<String> = []
    @State private var cleanDeadLinksRequest: UUID?
    @State private var deadLinkTask: Task<Void, Never>?
    @State private var showTaskBacklinks = false
    @State private var hoveredSubtaskID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if hasDeadLinks {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: DS.IconSize.xs))
                        .foregroundStyle(DS.Colors.warning)
                    Text("Contains broken links to deleted items")
                        .font(DS.Font.small)
                        .foregroundStyle(DS.Colors.textSecondary)
                    Spacer()
                    Button("Fix") { cleanDeadLinksRequest = UUID() }
                        .font(DS.Font.small)
                        .foregroundStyle(DS.Colors.warning)
                        .buttonStyle(.plainPointer)
                }
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.vertical, DS.Spacing.xs)
                .frame(maxWidth: .infinity)
                .background(DS.Colors.warning.opacity(0.08))
            }

            if task.isArchived {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "archivebox.fill")
                        .font(.system(size: DS.IconSize.xs, weight: .medium))
                    Text("Archived — unarchive to edit")
                        .font(DS.Font.caption)
                        .fontWeight(.medium)
                    Spacer()
                    Button("Unarchive") {
                        task.isArchived = false
                        task.manuallyArchived = false
                        task.modifiedAt = Date()
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

            TextField("What needs to be done?", text: $task.title)
                .textFieldStyle(.plain)
                .font(DS.Font.title)
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.top, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.md)
                .disabled(task.isArchived)

            // Compact metadata chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Spacing.sm) {
                    metadataChip(icon: task.status.icon, color: task.status.color, text: task.status.rawValue) {
                        ForEach(TaskStatus.allCases) { status in
                            Button { task.status = status } label: {
                                Label(status.rawValue, systemImage: status.icon)
                            }
                        }
                    }

                    metadataChip(icon: task.priority.icon, color: task.priority.color, text: task.priority.rawValue) {
                        ForEach(TaskPriority.allCases) { priority in
                            Button { task.priority = priority } label: {
                                Label(priority.rawValue, systemImage: priority.icon)
                            }
                        }
                    }

                    // Story points
                    metadataChip(icon: "number", color: DS.Colors.textSecondary, text: task.storyPoints.map { "\($0) pts" } ?? "Points") {
                        Button { task.storyPoints = nil } label: { Text("None") }
                        Divider()
                        ForEach(AppConstants.storyPointOptions, id: \.self) { point in
                            Button { task.storyPoints = point } label: { Text("\(point)") }
                        }
                        Divider()
                        Button { showCustomPoints = true } label: {
                            Label("Custom...", systemImage: "number.square")
                        }
                    }

                    // Due date
                    Button { showCalendar.toggle() } label: {
                        HStack(spacing: DS.Spacing.xs) {
                            Image(systemName: "calendar")
                                .font(.system(size: DS.IconSize.sm))
                                .foregroundStyle(dueDateColor)
                            Text(task.dueDate?.shortFormatted ?? "Due date")
                                .foregroundStyle(task.dueDate == nil ? DS.Colors.textTertiary : dueDateColor)
                        }
                        .font(DS.Font.caption)
                        .padding(.horizontal, DS.Spacing.sm2)
                        .padding(.vertical, DS.Spacing.xs2)
                        .background(DS.Colors.fillSecondary, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                    }
                    .buttonStyle(.plainPointer)
                    .popover(isPresented: $showCalendar) {
                        DSCalendarPicker(
                            selectedDate: Binding(
                                get: { task.dueDate },
                                set: { task.dueDate = $0 }
                            ),
                            isPresented: $showCalendar
                        )
                    }

                    // Project
                    metadataChip(
                        icon: "folder",
                        color: task.project.map { Color(hex: $0.color) } ?? DS.Colors.textSecondary,
                        text: task.project?.name ?? "Project"
                    ) {
                        Button { task.project = nil } label: { Text("None") }
                        Divider()
                        ForEach(projects) { project in
                            Button { task.project = project } label: {
                                Label(project.name, systemImage: "folder")
                            }
                        }
                    }
                }
                .padding(.horizontal, DS.Spacing.xl)
            }
            .padding(.bottom, DS.Spacing.md)
            .disabled(task.isArchived)

            Divider()

            // Subtasks
            VStack(alignment: .leading, spacing: 0) {
                Button {
                    withAnimation(DS.Animation.quick) { showSubtasks.toggle() }
                } label: {
                    HStack(spacing: DS.Spacing.sm) {
                        Image(systemName: showSubtasks ? "chevron.down" : "chevron.right")
                            .font(.system(size: DS.IconSize.xs, weight: .bold))
                            .foregroundStyle(DS.Colors.textTertiary)
                            .frame(width: 12)
                        Text("Subtasks")
                            .font(DS.Font.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(DS.Colors.textPrimary)
                        if !task.subtasks.isEmpty {
                            let done = task.subtasks.count(where: { $0.status == .done })
                            Text("\(done)/\(task.subtasks.count)")
                                .font(DS.Font.small)
                                .foregroundStyle(DS.Colors.textTertiary)
                        }
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plainPointer)
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.vertical, DS.Spacing.sm)

                if showSubtasks {
                    VStack(spacing: 0) {
                        ForEach(task.subtasks.sorted(by: { $0.createdAt < $1.createdAt })) { sub in
                            HStack(spacing: DS.Spacing.sm) {
                                Button {
                                    withAnimation(DS.Animation.quick) {
                                        sub.status = sub.status == .done ? .todo : .done
                                        sub.modifiedAt = Date()
                                    }
                                } label: {
                                    Image(systemName: sub.status == .done ? "checkmark.circle.fill" : "circle")
                                        .font(DS.Font.body)
                                        .foregroundStyle(sub.status == .done ? DS.Colors.success : DS.Colors.textTertiary)
                                }
                                .buttonStyle(.plainPointer)

                                Text(sub.title)
                                    .font(DS.Font.body)
                                    .strikethrough(sub.status == .done)
                                    .foregroundStyle(sub.status == .done ? DS.Colors.textTertiary : DS.Colors.textPrimary)
                                    .lineLimit(1)

                                Spacer()

                                Button {
                                    modelContext.delete(sub)
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: DS.IconSize.xs, weight: .bold))
                                        .foregroundStyle(DS.Colors.textTertiary)
                                }
                                .buttonStyle(.plainPointer)
                                .opacity(hoveredSubtaskID == sub.id ? 1.0 : 0.0)
                            }
                            .padding(.horizontal, DS.Spacing.xl)
                            .padding(.vertical, DS.Spacing.xs2)
                            .background(hoveredSubtaskID == sub.id ? DS.Colors.fill : .clear)
                            .contentShape(Rectangle())
                            .onHover { isHovering in
                                hoveredSubtaskID = isHovering ? sub.id : nil
                                if isHovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                            }
                            .animation(DS.Animation.quick, value: hoveredSubtaskID)
                        }

                        HStack(spacing: DS.Spacing.sm) {
                            Image(systemName: "plus.circle")
                                .font(DS.Font.body)
                                .foregroundStyle(DS.Colors.textTertiary)

                            TextField("Add subtask...", text: $newSubtaskTitle)
                                .textFieldStyle(.plain)
                                .font(DS.Font.body)
                                .onSubmit {
                                    addSubtask()
                                }
                        }
                        .padding(.horizontal, DS.Spacing.xl)
                        .padding(.vertical, DS.Spacing.xs2)
                    }
                }

                Divider()
                    .padding(.top, DS.Spacing.xs)
            }
            .disabled(task.isArchived)

            // Rich markdown editor (toolbar is built-in)
            RichMarkdownEditor(
                text: $task.detail,
                isReadOnly: task.isArchived,
                onLinkClick: { url in appState.handleDeepLink(url) },
                onRequestLinkInsert: { type in linkPickerType = type },
                linkInsertRequest: linkInsertRequest,
                deadLinkUUIDs: deadLinkUUIDs,
                onRequestDeadLinkClean: { hasDeadLinks = false; deadLinkUUIDs = [] },
                cleanDeadLinksRequest: cleanDeadLinksRequest
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .sheet(isPresented: Binding(get: { linkPickerType != nil }, set: { if !$0 { linkPickerType = nil } })) {
                if let type = linkPickerType {
                    DeepLinkPickerSheet(type: type, onSelect: { title, url in
                        linkInsertRequest = DeepLinkInsertRequest(text: title, url: url)
                        linkPickerType = nil
                    }, onDismiss: { linkPickerType = nil })
                }
            }

            let taskBacklinks = BacklinkService.shared.deepLinkBacklinks(forType: "task", id: task.id, in: allNotes)
            if !taskBacklinks.isEmpty {
                Divider()
                DeepLinkBacklinksPanel(
                    backlinks: taskBacklinks,
                    isExpanded: $showTaskBacklinks,
                    onNavigate: { appState.navigateToNote($0) }
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onChange(of: task.title) { task.modifiedAt = Date(); try? modelContext.save() }
        .onChange(of: task.detail) { task.modifiedAt = Date(); try? modelContext.save(); scheduleScanDeadLinks() }
        .onChange(of: task.statusRaw) { task.modifiedAt = Date(); try? modelContext.save() }
        .onChange(of: task.priorityRaw) { task.modifiedAt = Date(); try? modelContext.save() }
        .sheet(isPresented: $showCustomPoints) {
            CustomPointsSheet(points: $task.storyPoints, isPresented: $showCustomPoints)
        }
        .onAppear { scheduleScanDeadLinks() }
        .onChange(of: task.id) {
            newSubtaskTitle = ""
            deadLinkUUIDs = []
            hasDeadLinks = false
        }
    }

    private func scheduleScanDeadLinks() {
        deadLinkTask?.cancel()
        let content = task.detail
        let tasks = allTasksForScan, notes = allNotes, reminders = allReminders
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

    private func addSubtask() {
        let title = newSubtaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        let sub = TaskItem(title: title)
        sub.parent = task
        sub.project = task.project
        modelContext.insert(sub)
        newSubtaskTitle = ""
    }

    private var dueDateColor: Color {
        task.isOverdue ? DS.Colors.danger : DS.Colors.textPrimary
    }

    private func metadataChip(
        icon: String,
        color: Color,
        text: String,
        @ViewBuilder menu: () -> some View
    ) -> some View {
        Menu {
            menu()
        } label: {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: DS.IconSize.sm))
                    .foregroundStyle(color)
                Text(text)
            }
            .font(DS.Font.caption)
            .padding(.horizontal, DS.Spacing.sm2)
            .padding(.vertical, DS.Spacing.xs2)
            .background(DS.Colors.fillSecondary, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
        }
        .buttonStyle(.plainPointer)
    }
}

// MARK: - Deep Link Backlinks Panel

private struct DeepLinkBacklinksPanel: View {
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
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: DS.IconSize.xs))
                        .foregroundStyle(DS.Colors.textTertiary)
                    Text("^[\(backlinks.count) note](inflect: true) references this task")
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
                    ForEach(backlinks) { note in
                        Button { onNavigate(note.id) } label: {
                            HStack(spacing: DS.Spacing.sm) {
                                Image(systemName: "doc.text")
                                    .font(.system(size: DS.IconSize.xs))
                                    .foregroundStyle(DS.Colors.accent)
                                Text(note.title.isEmpty ? "Untitled" : note.title)
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

// MARK: - Custom Points Sheet

private struct CustomPointsSheet: View {
    @Binding var points: Int?
    @Binding var isPresented: Bool
    @State private var text = ""

    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            Text("Custom Story Points")
                .font(DS.Font.heading)

            TextField("Enter points", text: $text)
                .textFieldStyle(.plain)
                .font(DS.Font.body)
                .frame(width: 120)
                .dsInputField()
                .onSubmit { apply() }

            HStack(spacing: DS.Spacing.md) {
                Button("Cancel") { isPresented = false }
                    .buttonStyle(.plainPointer)
                Button("Apply") { apply() }
                    .buttonStyle(.dsPrimary)
                    .disabled(Int(text) == nil)
            }
        }
        .padding(DS.Spacing.xl)
        .frame(width: 240)
    }

    private func apply() {
        if let val = Int(text) {
            points = val
        }
        isPresented = false
    }
}
