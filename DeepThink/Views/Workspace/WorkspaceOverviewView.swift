import SwiftUI
import SwiftData

struct WorkspaceOverviewView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query private var notes: [Note]
    @Query private var tasks: [TaskItem]
    @Query private var projects: [Project]

    private var recentNotes: [Note] {
        notes.sorted { $0.modifiedAt > $1.modifiedAt }.prefix(5).map { $0 }
    }

    private var recentActiveTasks: [TaskItem] {
        tasks
            .filter { $0.status != .done && $0.status != .cancelled }
            .sorted { $0.modifiedAt > $1.modifiedAt }
            .prefix(5)
            .map { $0 }
    }

    private var inProgressCount: Int {
        tasks.filter { $0.status == .inProgress }.count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                HStack(spacing: DS.Spacing.md) {
                    statCard(icon: "folder", label: "Projects", count: projects.count, color: .blue)
                    statCard(icon: "doc.text", label: "Notes", count: notes.count, color: .green)
                    statCard(icon: "checklist", label: "Tasks", count: tasks.count, color: .orange)
                    statCard(icon: "circle.lefthalf.filled", label: "In Progress", count: inProgressCount, color: .purple)
                }

                HStack(alignment: .top, spacing: DS.Spacing.xl) {
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        DSSectionHeader(title: "Recent Notes", count: notes.count) {
                            appState.workspaceTab = .notes
                        }

                        if recentNotes.isEmpty {
                            emptyCard(icon: "doc.text", text: "No notes yet")
                        } else {
                            VStack(spacing: 0) {
                                ForEach(recentNotes) { note in
                                    Button {
                                        appState.selectedNoteID = note.id
                                        appState.workspaceTab = .notes
                                    } label: {
                                        HStack(spacing: DS.Spacing.md) {
                                            Image(systemName: "doc.text")
                                                .font(.system(size: DS.IconSize.sm))
                                                .foregroundStyle(DS.Colors.textTertiary)
                                                .frame(width: 20)

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(note.title.isEmpty ? "Untitled" : note.title)
                                                    .font(DS.Font.body)
                                                    .foregroundStyle(DS.Colors.textPrimary)
                                                    .lineLimit(1)

                                                if let project = note.project {
                                                    Text(project.name)
                                                        .font(DS.Font.tiny)
                                                        .foregroundStyle(DS.Colors.textTertiary)
                                                }
                                            }

                                            Spacer()

                                            Text(note.modifiedAt.relativeFormatted)
                                                .font(DS.Font.tiny)
                                                .foregroundStyle(DS.Colors.textTertiary)
                                        }
                                        .padding(.horizontal, DS.Spacing.md)
                                        .padding(.vertical, DS.Spacing.sm)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plainPointer)

                                    if note.id != recentNotes.last?.id {
                                        Divider().padding(.leading, 20 + DS.Spacing.md)
                                    }
                                }
                            }
                            .dsCard(padding: 0)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .top)

                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        DSSectionHeader(title: "Active Tasks", count: recentActiveTasks.count) {
                            appState.workspaceTab = .tasks
                        }

                        if recentActiveTasks.isEmpty {
                            emptyCard(icon: "checklist", text: "No active tasks")
                        } else {
                            VStack(spacing: 0) {
                                ForEach(recentActiveTasks) { task in
                                    Button {
                                        appState.selectedTaskID = task.id
                                        appState.workspaceTab = .tasks
                                    } label: {
                                        HStack(spacing: DS.Spacing.md) {
                                            Image(systemName: task.status.icon)
                                                .font(.system(size: DS.IconSize.sm))
                                                .foregroundStyle(task.status.color)
                                                .frame(width: 20)

                                            Text(task.title.isEmpty ? "Untitled" : task.title)
                                                .font(DS.Font.body)
                                                .foregroundStyle(DS.Colors.textPrimary)
                                                .lineLimit(1)

                                            Spacer()

                                            if task.priority != .none {
                                                DSPill(text: task.priority.rawValue, color: task.priority.color)
                                            }
                                        }
                                        .padding(.horizontal, DS.Spacing.md)
                                        .padding(.vertical, DS.Spacing.sm)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plainPointer)

                                    if task.id != recentActiveTasks.last?.id {
                                        Divider().padding(.leading, 20 + DS.Spacing.md)
                                    }
                                }
                            }
                            .dsCard(padding: 0)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .top)
                }

                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    DSSectionHeader(title: "Quick Actions")

                    HStack(spacing: DS.Spacing.md) {
                        DSActionButton(title: "New Note", icon: "doc.text.badge.plus", color: .green) {
                            appState.workspaceTab = .notes
                            NotificationCenter.default.post(name: .createNewNote, object: nil)
                        }

                        DSActionButton(title: "New Task", icon: "plus.circle", color: .orange) {
                            appState.workspaceTab = .tasks
                            NotificationCenter.default.post(name: .createNewTask, object: nil)
                        }

                        DSActionButton(title: "New Project", icon: "folder.badge.plus", color: .blue) {
                            appState.workspaceTab = .projects
                            NotificationCenter.default.post(name: .createNewProject, object: nil)
                        }
                    }
                }
            }
            .padding(DS.Spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func statCard(icon: String, label: String, count: Int, color: Color) -> some View {
        VStack(spacing: DS.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: DS.IconSize.lg, weight: .medium))
                .foregroundStyle(color)

            Text("\(count)")
                .font(DS.Font.title)
                .fontWeight(.bold)
                .foregroundStyle(DS.Colors.textPrimary)

            Text(label)
                .font(DS.Font.caption)
                .foregroundStyle(DS.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(DS.Spacing.lg)
        .background(DS.Colors.subtleBg, in: RoundedRectangle(cornerRadius: DS.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg)
                .strokeBorder(DS.Colors.borderSubtle, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func emptyCard(icon: String, text: String) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: DS.IconSize.md))
                .foregroundStyle(DS.Colors.textTertiary)
            Text(text)
                .font(DS.Font.body)
                .foregroundStyle(DS.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(DS.Spacing.xl)
        .background(DS.Colors.subtleBg, in: RoundedRectangle(cornerRadius: DS.Radius.md))
    }
}
