import SwiftUI
import SwiftData

struct ProjectDetailView: View {
    @Bindable var project: Project
    @State private var selectedTab = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: DS.Spacing.sm) {
                Circle()
                    .fill(Color(hex: project.color))
                    .frame(width: 10, height: 10)

                TextField("Project name", text: $project.name)
                    .textFieldStyle(.plain)
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.top, DS.Spacing.lg)

            TextField("Add a summary...", text: $project.summary, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.top, DS.Spacing.xs)

            HStack(spacing: DS.Spacing.md) {
                StatChip(label: "Notes", value: "\(project.notes.count)", icon: "doc.text")
                StatChip(label: "Tasks", value: "\(project.openTaskCount) open", icon: "checklist")
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.top, DS.Spacing.md)

            Picker("", selection: $selectedTab) {
                Text("Tasks").tag(0)
                Text("Notes").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.top, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.sm)

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
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: icon)
                .font(DS.Font.tiny)
            Text(value)
                .font(DS.Font.caption)
                .fontWeight(.medium)
        }
        .foregroundStyle(DS.Colors.textSecondary)
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.xs)
        .background(Color.primary.opacity(0.04), in: Capsule())
    }
}
