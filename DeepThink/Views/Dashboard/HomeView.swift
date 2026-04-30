import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @Query private var notes: [Note]
    @Query private var tasks: [TaskItem]
    @Query(filter: #Predicate<Project> { !$0.isArchived }) private var projects: [Project]
    @Query(filter: #Predicate<MCPServer> { $0.isEnabled }) private var activeTools: [MCPServer]
    @State private var quickQuery = ""

    private var activeTasks: [TaskItem] {
        tasks.filter { $0.status == .inProgress || $0.status == .todo }
            .sorted { $0.priority.sortOrder < $1.priority.sortOrder }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good morning" }
        if hour < 17 { return "Good afternoon" }
        return "Good evening"
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: DS.Spacing.xxl) {
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    Text(greeting)
                        .font(DS.Font.hero)
                    Text("What would you like to explore?")
                        .font(DS.Font.body)
                        .foregroundStyle(DS.Colors.textSecondary)
                }

                DSSearchField(
                    text: $quickQuery,
                    placeholder: "Ask anything... search, analyze, create",
                    icon: "sparkle.magnifyingglass"
                ) {
                    guard !quickQuery.isEmpty else { return }
                    appState.selectedSection = .chat
                    appState.pendingChatMessage = quickQuery
                    quickQuery = ""
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: DS.Spacing.md) {
                    HomeCard(title: "AI Chat", subtitle: "Claude-powered", icon: "bubble.left.and.bubble.right", color: .purple) {
                        appState.selectedSection = .chat
                    }
                    HomeCard(title: "Deep Search", subtitle: "Semantic search", icon: "sparkle.magnifyingglass", color: .orange) {
                        appState.selectedSection = .deepSearch
                    }
                    HomeCard(title: "Tools", subtitle: "\(activeTools.count) active", icon: "wrench.and.screwdriver", color: .indigo) {
                        appState.selectedSection = .tools
                    }
                    HomeCard(title: "Graph", subtitle: "Connections", icon: "point.3.connected.trianglepath.dotted", color: .cyan) {
                        appState.selectedSection = .graph
                    }
                }

                HStack(spacing: DS.Spacing.md) {
                    StatPill(value: "\(tasks.count)", label: "Tasks", icon: "checklist", color: .green)
                    StatPill(value: "\(tasks.filter { $0.status == .inProgress }.count)", label: "Active", icon: "arrow.triangle.2.circlepath", color: .orange)
                    StatPill(value: "\(tasks.filter { $0.status == .done }.count)", label: "Done", icon: "checkmark.circle", color: .green)
                    StatPill(value: "\(notes.count)", label: "Notes", icon: "doc.text", color: .blue)
                    StatPill(value: "\(projects.count)", label: "Projects", icon: "folder", color: .teal)
                    StatPill(value: "\(activeTools.count)", label: "MCP Tools", icon: "wrench", color: .indigo)
                }

                HStack(alignment: .top, spacing: DS.Spacing.lg) {
                    VStack(alignment: .leading, spacing: DS.Spacing.md) {
                        DSSectionHeader(title: "Active Tasks", count: activeTasks.count) {
                            appState.selectedSection = .tasks
                        }

                        DSCard {
                            if activeTasks.isEmpty {
                                Text("All clear")
                                    .font(DS.Font.body)
                                    .foregroundStyle(DS.Colors.textTertiary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, DS.Spacing.xxl)
                            } else {
                                VStack(spacing: 0) {
                                    ForEach(Array(activeTasks.prefix(7).enumerated()), id: \.element.id) { i, task in
                                        if i > 0 { Divider().padding(.horizontal, DS.Spacing.xs) }
                                        HStack(spacing: DS.Spacing.sm) {
                                            Image(systemName: task.status.icon)
                                                .font(.system(size: 11))
                                                .foregroundStyle(task.status.color)
                                                .frame(width: 16)
                                            Text(task.title)
                                                .font(DS.Font.body)
                                                .lineLimit(1)
                                            Spacer()
                                            if let sp = task.storyPoints {
                                                DSPill(text: "\(sp)", color: .blue)
                                            }
                                            Image(systemName: task.priority.icon)
                                                .font(.system(size: 10))
                                                .foregroundStyle(task.priority.color)
                                        }
                                        .padding(.vertical, DS.Spacing.sm)
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)

                    VStack(alignment: .leading, spacing: DS.Spacing.md) {
                        DSSectionHeader(title: "Recent Notes", count: notes.count) {
                            appState.selectedSection = .notes
                        }

                        DSCard {
                            if notes.isEmpty {
                                Text("No notes yet")
                                    .font(DS.Font.body)
                                    .foregroundStyle(DS.Colors.textTertiary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, DS.Spacing.xxl)
                            } else {
                                VStack(spacing: 0) {
                                    ForEach(Array(notes.sorted { $0.modifiedAt > $1.modifiedAt }.prefix(7).enumerated()), id: \.element.id) { i, note in
                                        if i > 0 { Divider().padding(.horizontal, DS.Spacing.xs) }
                                        HStack(spacing: DS.Spacing.sm) {
                                            Image(systemName: note.isPinned ? "pin.fill" : "doc.text")
                                                .font(.system(size: 11))
                                                .foregroundStyle(note.isPinned ? .orange : DS.Colors.textTertiary)
                                                .frame(width: 16)
                                            Text(note.title.isEmpty ? "Untitled" : note.title)
                                                .font(DS.Font.body)
                                                .lineLimit(1)
                                            Spacer()
                                            Text(note.modifiedAt.relativeFormatted)
                                                .font(DS.Font.tiny)
                                                .foregroundStyle(DS.Colors.textTertiary)
                                        }
                                        .padding(.vertical, DS.Spacing.sm)
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }

                if !projects.isEmpty {
                    VStack(alignment: .leading, spacing: DS.Spacing.md) {
                        DSSectionHeader(title: "Projects", count: projects.count) {
                            appState.selectedSection = .projects
                        }

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: DS.Spacing.md) {
                            ForEach(projects.prefix(6)) { project in
                                DSCard(padding: DS.Spacing.md) {
                                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                                        HStack(spacing: DS.Spacing.sm) {
                                            Circle().fill(Color(hex: project.color)).frame(width: 8, height: 8)
                                            Text(project.name)
                                                .font(DS.Font.body)
                                                .fontWeight(.medium)
                                                .lineLimit(1)
                                        }
                                        if project.totalStoryPoints > 0 {
                                            ProgressView(value: Double(project.completedStoryPoints) / Double(project.totalStoryPoints))
                                                .tint(Color(hex: project.color))
                                        }
                                        HStack(spacing: DS.Spacing.sm) {
                                            DSPill(text: "\(project.openTaskCount) open", color: .orange)
                                            DSPill(text: "\(project.notes.count) notes", color: .blue)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(DS.Spacing.xxl)
        }
        .dsPage()
    }
}

private struct HomeCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                DSIconBadge(icon: icon, color: color, size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(DS.Font.body).fontWeight(.semibold).foregroundStyle(DS.Colors.textPrimary)
                    Text(subtitle).font(DS.Font.tiny).foregroundStyle(DS.Colors.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .dsGlass(padding: DS.Spacing.lg)
        }
        .buttonStyle(.plain)
    }
}

private struct StatPill: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
            Text(label)
                .font(DS.Font.tiny)
                .foregroundStyle(DS.Colors.textSecondary)
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
    }
}
