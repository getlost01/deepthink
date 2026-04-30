import SwiftUI
import SwiftData

struct ProjectDetailView: View {
    @Bindable var project: Project
    @State private var selectedTab = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color(hex: project.color))
                    .frame(width: 16, height: 16)

                TextField("Project name", text: $project.name)
                    .textFieldStyle(.plain)
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            TextField("Add a summary...", text: $project.summary, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .padding(.horizontal, 20)
                .padding(.top, 4)

            HStack(spacing: 16) {
                StatChip(label: "Notes", value: "\(project.notes.count)", icon: "doc.text")
                StatChip(label: "Tasks", value: "\(project.openTaskCount) open", icon: "checklist")
                StatChip(label: "Points", value: "\(project.completedStoryPoints)/\(project.totalStoryPoints)", icon: "chart.bar")
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            Picker("", selection: $selectedTab) {
                Text("Tasks").tag(0)
                Text("Notes").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 8)

            Divider()

            if selectedTab == 0 {
                List {
                    ForEach(project.tasks.sorted(by: { $0.status.sortOrder < $1.status.sortOrder })) { task in
                        TaskRowView(task: task)
                    }
                }
                .listStyle(.inset)
            } else {
                List {
                    ForEach(project.notes.sorted(by: { $0.modifiedAt > $1.modifiedAt })) { note in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(note.title.isEmpty ? "Untitled" : note.title)
                                .fontWeight(.medium)
                            Text(note.modifiedAt.relativeFormatted)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onChange(of: project.name) { project.modifiedAt = Date() }
        .onChange(of: project.summary) { project.modifiedAt = Date() }
    }
}

private struct StatChip: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.quaternary.opacity(0.5), in: Capsule())
    }
}
