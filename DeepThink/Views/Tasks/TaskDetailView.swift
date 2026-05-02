import SwiftUI
import SwiftData

struct TaskDetailView: View {
    @Bindable var task: TaskItem
    @Query(filter: #Predicate<Project> { !$0.isArchived }) private var projects: [Project]
    @State private var showCustomPoints = false
    @State private var customPointsText = ""
    @State private var showCalendar = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField("What needs to be done?", text: $task.title)
                .textFieldStyle(.plain)
                .font(DS.Font.title)
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.top, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.md)

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
                                .font(.system(size: DS.IconSize.xs))
                                .foregroundStyle(dueDateColor)
                            Text(task.dueDate?.shortFormatted ?? "Due date")
                                .foregroundStyle(task.dueDate == nil ? DS.Colors.textTertiary : dueDateColor)
                        }
                        .font(DS.Font.caption)
                        .padding(.horizontal, DS.Spacing.sm + 2)
                        .padding(.vertical, DS.Spacing.xs + 2)
                        .background(DS.Colors.inputBg, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
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

            // Rich markdown editor (toolbar is built-in)
            RichMarkdownEditor(text: $task.detail)
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

    private var dueDateColor: Color {
        task.isOverdue ? DS.Colors.error : DS.Colors.textPrimary
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
                    .font(.system(size: DS.IconSize.xs))
                    .foregroundStyle(color)
                Text(text)
            }
            .font(DS.Font.caption)
            .padding(.horizontal, DS.Spacing.sm + 2)
            .padding(.vertical, DS.Spacing.xs + 2)
            .background(DS.Colors.inputBg, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
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
                    .buttonStyle(.borderedProminent)
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

