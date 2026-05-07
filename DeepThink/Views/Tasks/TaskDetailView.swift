import SwiftUI
import SwiftData

struct TaskDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var task: TaskItem
    @Query private var projects: [Project]
    @State private var showCustomPoints = false
    @State private var customPointsText = ""
    @State private var showCalendar = false
    @State private var newSubtaskTitle = ""
    @State private var showSubtasks = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
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
                        .padding(.horizontal, DS.Spacing.sm + 2)
                        .padding(.vertical, DS.Spacing.xs + 2)
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
                            let done = task.subtasks.filter { $0.status == .done }.count
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
                                        .font(.system(size: 13))
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
                                .opacity(0.5)
                            }
                            .padding(.horizontal, DS.Spacing.xl)
                            .padding(.vertical, DS.Spacing.xs + 1)
                            .pointerOnHover()
                        }

                        HStack(spacing: DS.Spacing.sm) {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 13))
                                .foregroundStyle(DS.Colors.textTertiary)

                            TextField("Add subtask...", text: $newSubtaskTitle)
                                .textFieldStyle(.plain)
                                .font(DS.Font.body)
                                .onSubmit {
                                    addSubtask()
                                }
                        }
                        .padding(.horizontal, DS.Spacing.xl)
                        .padding(.vertical, DS.Spacing.xs + 1)
                    }
                }

                Divider()
                    .padding(.top, DS.Spacing.xs)
            }
            .disabled(task.isArchived)

            // Rich markdown editor (toolbar is built-in)
            RichMarkdownEditor(text: $task.detail, isReadOnly: task.isArchived)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onChange(of: task.title) { task.modifiedAt = Date() }
        .onChange(of: task.detail) { task.modifiedAt = Date() }
        .onChange(of: task.statusRaw) { task.modifiedAt = Date() }
        .onChange(of: task.priorityRaw) { task.modifiedAt = Date() }
        .sheet(isPresented: $showCustomPoints) {
            CustomPointsSheet(points: $task.storyPoints, isPresented: $showCustomPoints)
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

    @ViewBuilder
    private func metadataChip<MenuContent: View>(
        icon: String,
        color: Color,
        text: String,
        @ViewBuilder menu: () -> MenuContent
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
            .padding(.horizontal, DS.Spacing.sm + 2)
            .padding(.vertical, DS.Spacing.xs + 2)
            .background(DS.Colors.fillSecondary, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
        }
        .buttonStyle(.plainPointer)
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
                .textFieldStyle(.roundedBorder)
                .frame(width: 120)
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

