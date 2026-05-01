import SwiftUI
import SwiftData

struct ProjectInspectorView: View {
    @Environment(AppState.self) private var appState
    @Query private var allProjects: [Project]

    private var selectedProject: Project? {
        guard let id = appState.selectedProjectID else { return nil }
        return allProjects.first { $0.id == id }
    }

    var body: some View {
        Group {
            if let project = selectedProject {
                ProjectInspectorContent(project: project)
            } else {
                VStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "folder")
                        .font(.system(size: 24, weight: .light))
                        .foregroundStyle(DS.Colors.textTertiary)
                    Text("Select a project")
                        .foregroundStyle(DS.Colors.textSecondary)
                        .font(DS.Font.caption)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

private struct ProjectInspectorContent: View {
    @Bindable var project: Project

    private let colorOptions = ["#007AFF", "#FF3B30", "#FF9500", "#34C759", "#5856D6", "#AF52DE", "#FF2D55", "#A2845E"]

    var body: some View {
        Form {
            Section("Details") {
                LabeledContent("Created", value: project.createdAt.shortFormatted)
                LabeledContent("Modified", value: project.modifiedAt.relativeFormatted)
                Toggle("Archived", isOn: $project.isArchived)
            }

            Section("Color") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: DS.Spacing.sm) {
                    ForEach(colorOptions, id: \.self) { hex in
                        Circle()
                            .fill(Color(hex: hex))
                            .frame(width: 24, height: 24)
                            .overlay {
                                if project.color == hex {
                                    Image(systemName: "checkmark")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .foregroundStyle(.white)
                                }
                            }
                            .onTapGesture {
                                project.color = hex
                            }
                    }
                }
            }

            Section("Stats") {
                LabeledContent("Total Tasks", value: "\(project.tasks.count)")
                LabeledContent("Completed", value: "\(project.completedTaskCount)")
                LabeledContent("Open", value: "\(project.openTaskCount)")
                LabeledContent("Total Points", value: "\(project.totalStoryPoints)")
                LabeledContent("Completed Points", value: "\(project.completedStoryPoints)")
                LabeledContent("Notes", value: "\(project.notes.count)")
            }

            if project.totalStoryPoints > 0 {
                Section("Progress") {
                    let progress = Double(project.completedStoryPoints) / Double(project.totalStoryPoints)
                    ProgressView(value: progress)
                        .tint(DS.Colors.accent)
                    Text("\(Int(progress * 100))% complete")
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Colors.textSecondary)
                }
            }
        }
        .formStyle(.grouped)
    }
}
