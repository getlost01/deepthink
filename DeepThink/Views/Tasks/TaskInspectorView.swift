import SwiftUI
import SwiftData

struct TaskInspectorView: View {
    @Environment(AppState.self) private var appState
    @Query private var allTasks: [TaskItem]

    private var selectedTask: TaskItem? {
        guard let id = appState.selectedTaskID else { return nil }
        return allTasks.first { $0.id == id }
    }

    var body: some View {
        Group {
            if let task = selectedTask {
                TaskInspectorContent(task: task)
            } else {
                VStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "checklist")
                        .font(.system(size: 24, weight: .light))
                        .foregroundStyle(DS.Colors.textTertiary)
                    Text("Select a task")
                        .foregroundStyle(DS.Colors.textSecondary)
                        .font(DS.Font.caption)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

private struct TaskInspectorContent: View {
    let task: TaskItem
    @Environment(AppState.self) private var appState

    var body: some View {
        Form {
            Section("Status") {
                LabeledContent("Status") {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: task.status.icon)
                            .foregroundStyle(task.status.color)
                        Text(task.status.rawValue)
                    }
                }
                LabeledContent("Priority") {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: task.priority.icon)
                            .foregroundStyle(task.priority.color)
                        Text(task.priority.rawValue)
                    }
                }
                if let points = task.storyPoints {
                    LabeledContent("Story Points", value: "\(points)")
                }
            }

            Section("Dates") {
                LabeledContent("Created", value: task.createdAt.shortFormatted)
                LabeledContent("Modified", value: task.modifiedAt.relativeFormatted)
                if let due = task.dueDate {
                    LabeledContent("Due") {
                        Text(due.shortFormatted)
                            .foregroundStyle(task.isOverdue ? DS.Colors.danger : DS.Colors.textPrimary)
                    }
                }
                if let completed = task.completedAt {
                    LabeledContent("Completed", value: completed.shortFormatted)
                }
            }

            if let project = task.project {
                Section("Project") {
                    Button {
                        appState.navigateToProject(project.id)
                    } label: {
                        HStack(spacing: DS.Spacing.sm) {
                            Circle()
                                .fill(Color(hex: project.color))
                                .frame(width: 8, height: 8)
                            Text(project.name)
                                .foregroundStyle(DS.Colors.accent)
                            Spacer()
                            Image(systemName: "arrow.right")
                                .font(.system(size: DS.IconSize.sm))
                                .foregroundStyle(DS.Colors.textTertiary)
                        }
                    }
                    .buttonStyle(.plainPointer)
                }
            }

            if !task.tags.isEmpty {
                Section("Tags") {
                    FlowLayout(spacing: DS.Spacing.xs) {
                        ForEach(task.tags) { tag in
                            TagChip(tag: tag)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}
