import SwiftUI
import SwiftData

struct ProjectDetailView: View {
    @Bindable var project: Project
    @State private var selectedTab = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    HStack(spacing: DS.Spacing.md) {
                        Circle()
                            .fill(Color(hex: project.color))
                            .frame(width: 12, height: 12)

                        TextField("Project name", text: $project.name)
                            .textFieldStyle(.plain)
                            .font(DS.Font.detailTitle)
                    }

                    TextField("Add a summary...", text: $project.summary, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(DS.Font.bodyLarge)
                        .foregroundStyle(DS.Colors.textSecondary)
                        .lineLimit(2)

                    HStack(spacing: DS.Spacing.sm) {
                        DSStatChip(label: "Notes", value: "\(project.notes.count)", icon: "doc.text")
                        DSStatChip(label: "Tasks", value: "\(project.openTaskCount) open", icon: "checklist")
                        if project.totalStoryPoints > 0 {
                            DSStatChip(label: "Points", value: "\(project.completedStoryPoints)/\(project.totalStoryPoints)", icon: "star")
                        }
                    }

                    if project.totalStoryPoints > 0 {
                        let progress = Double(project.completedStoryPoints) / Double(project.totalStoryPoints)
                        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                            ProgressView(value: progress)
                                .tint(DS.Colors.accent)
                            Text("\(Int(progress * 100))% complete")
                                .font(DS.Font.caption)
                                .foregroundStyle(DS.Colors.textTertiary)
                        }
                    }
                }
                .padding(DS.Spacing.xl)

                Divider()
                    .padding(.horizontal, DS.Spacing.xl)

                Picker("", selection: $selectedTab) {
                    Text("Tasks").tag(0)
                    Text("Notes").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.vertical, DS.Spacing.md)

                if selectedTab == 0 {
                    projectTasksList
                } else {
                    projectNotesList
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onChange(of: project.name) { project.modifiedAt = Date() }
        .onChange(of: project.summary) { project.modifiedAt = Date() }
    }

    @ViewBuilder
    private var projectTasksList: some View {
        if project.tasks.isEmpty {
            VStack(spacing: DS.Spacing.md) {
                Image(systemName: "checklist")
                    .font(.system(size: 24, weight: .light))
                    .foregroundStyle(DS.Colors.textTertiary)
                Text("No tasks yet")
                    .font(DS.Font.body)
                    .foregroundStyle(DS.Colors.textSecondary)
                Text("Tasks assigned to this project will appear here")
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Colors.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, DS.Spacing.xxxl)
        } else {
            VStack(spacing: 0) {
                ForEach(project.tasks.sorted(by: { $0.status.sortOrder < $1.status.sortOrder })) { task in
                    HStack(spacing: DS.Spacing.md) {
                        Image(systemName: task.status.icon)
                            .font(.system(size: DS.IconSize.sm, weight: .medium))
                            .foregroundStyle(task.status.color)
                            .frame(width: 20)

                        Text(task.title)
                            .font(DS.Font.body)
                            .lineLimit(1)

                        Spacer()

                        if task.priority != .none {
                            Image(systemName: task.priority.icon)
                                .font(.system(size: DS.IconSize.sm))
                                .foregroundStyle(task.priority.color)
                        }
                    }
                    .padding(.horizontal, DS.Spacing.xl)
                    .padding(.vertical, DS.Spacing.md)

                    if task.id != project.tasks.last?.id {
                        Divider()
                            .padding(.leading, DS.Spacing.xl + 20 + DS.Spacing.md)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var projectNotesList: some View {
        if project.notes.isEmpty {
            VStack(spacing: DS.Spacing.md) {
                Image(systemName: "doc.text")
                    .font(.system(size: 24, weight: .light))
                    .foregroundStyle(DS.Colors.textTertiary)
                Text("No notes yet")
                    .font(DS.Font.body)
                    .foregroundStyle(DS.Colors.textSecondary)
                Text("Notes linked to this project will appear here")
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Colors.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, DS.Spacing.xxxl)
        } else {
            VStack(spacing: 0) {
                ForEach(project.notes.sorted(by: { $0.modifiedAt > $1.modifiedAt })) { note in
                    HStack(spacing: DS.Spacing.md) {
                        Image(systemName: "doc.text")
                            .font(.system(size: DS.IconSize.sm, weight: .medium))
                            .foregroundStyle(DS.Colors.textTertiary)
                            .frame(width: 20)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(note.title.isEmpty ? "Untitled" : note.title)
                                .font(DS.Font.body)
                                .fontWeight(.medium)
                                .lineLimit(1)
                            Text(note.modifiedAt.relativeFormatted)
                                .font(DS.Font.tiny)
                                .foregroundStyle(DS.Colors.textTertiary)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, DS.Spacing.xl)
                    .padding(.vertical, DS.Spacing.md)

                    if note.id != project.notes.last?.id {
                        Divider()
                            .padding(.leading, DS.Spacing.xl + 20 + DS.Spacing.md)
                    }
                }
            }
        }
    }
}
