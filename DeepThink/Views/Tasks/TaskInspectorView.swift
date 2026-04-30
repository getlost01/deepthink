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
                VStack(spacing: 8) {
                    Image(systemName: "checklist")
                        .font(.title2)
                        .foregroundStyle(.tertiary)
                    Text("Select a task")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

private struct TaskInspectorContent: View {
    let task: TaskItem

    var body: some View {
        Form {
            Section("Status") {
                LabeledContent("Status") {
                    HStack(spacing: 4) {
                        Image(systemName: task.status.icon)
                            .foregroundStyle(task.status.color)
                        Text(task.status.rawValue)
                    }
                }
                LabeledContent("Priority") {
                    HStack(spacing: 4) {
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
                            .foregroundStyle(task.isOverdue ? .red : .primary)
                    }
                }
                if let completed = task.completedAt {
                    LabeledContent("Completed", value: completed.shortFormatted)
                }
            }

            if let project = task.project {
                Section("Project") {
                    HStack {
                        Circle()
                            .fill(Color(hex: project.color))
                            .frame(width: 8, height: 8)
                        Text(project.name)
                    }
                }
            }

            if !task.tags.isEmpty {
                Section("Tags") {
                    FlowLayout(spacing: 4) {
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
