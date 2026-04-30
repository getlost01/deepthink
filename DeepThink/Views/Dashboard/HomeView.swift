import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @Query private var notes: [Note]
    @Query private var tasks: [TaskItem]
    @Query(filter: #Predicate<Project> { !$0.isArchived }) private var projects: [Project]
    @Query(filter: #Predicate<MCPServer> { $0.isEnabled }) private var activeTools: [MCPServer]
    @State private var quickQuery = ""
    @State private var memoryShort = 0
    @State private var memoryLong = 0
    @State private var cliAvailable = false

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

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DS.Spacing.md) {
                    HomeCard(title: "AI Chat", icon: "bubble.left.and.bubble.right", color: .blue) {
                        appState.selectedSection = .chat
                    }
                    HomeCard(title: "Deep Search", icon: "sparkle.magnifyingglass", color: .orange) {
                        appState.selectedSection = .deepSearch
                    }
                    HomeCard(title: "Memory", icon: "brain", color: .purple, badge: memoryShort + memoryLong > 0 ? "\(memoryShort + memoryLong)" : nil) {
                        appState.selectedSection = .memory
                    }
                    HomeCard(title: "Analysis", icon: "wand.and.rays", color: .green) {
                        appState.selectedSection = .analysis
                    }
                    HomeCard(title: "Tools", icon: "wrench.and.screwdriver", color: .teal) {
                        appState.selectedSection = .tools
                    }
                    HomeCard(title: "Graph", icon: "point.3.connected.trianglepath.dotted", color: .cyan) {
                        appState.selectedSection = .graph
                    }
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
                                    ForEach(Array(activeTasks.prefix(5).enumerated()), id: \.element.id) { i, task in
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
                                    ForEach(Array(notes.sorted { $0.modifiedAt > $1.modifiedAt }.prefix(5).enumerated()), id: \.element.id) { i, note in
                                        if i > 0 { Divider().padding(.horizontal, DS.Spacing.xs) }
                                        HStack(spacing: DS.Spacing.sm) {
                                            Image(systemName: "doc.text")
                                                .font(.system(size: 11))
                                                .foregroundStyle(DS.Colors.textTertiary)
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

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DS.Spacing.md) {
                            ForEach(projects.prefix(4)) { project in
                                DSCard(padding: DS.Spacing.md) {
                                    HStack(spacing: DS.Spacing.sm) {
                                        Circle().fill(Color(hex: project.color)).frame(width: 8, height: 8)
                                        Text(project.name)
                                            .font(DS.Font.body)
                                            .fontWeight(.medium)
                                            .lineLimit(1)
                                        Spacer()
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
        .onAppear { loadMemoryStats() }
    }

    private func loadMemoryStats() {
        Task {
            let result = await DeepThinkCLIService.shared.memoryStats()
            await MainActor.run {
                cliAvailable = result.success
                if result.success {
                    for line in result.output.components(separatedBy: "\n") {
                        if line.contains("Short-term:") {
                            memoryShort = Int(line.components(separatedBy: ": ").last?.components(separatedBy: " ").first ?? "0") ?? 0
                        }
                        if line.contains("Long-term:") {
                            memoryLong = Int(line.components(separatedBy: ": ").last?.components(separatedBy: " ").first ?? "0") ?? 0
                        }
                    }
                }
            }
        }
    }
}

private struct HomeCard: View {
    let title: String
    let icon: String
    let color: Color
    var badge: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                HStack {
                    DSIconBadge(icon: icon, color: color, size: 36)
                    Spacer()
                    if let badge {
                        Text(badge)
                            .font(DS.Font.tiny)
                            .fontWeight(.medium)
                            .foregroundStyle(color)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(color.opacity(0.1), in: Capsule())
                    }
                }
                Text(title).font(DS.Font.body).fontWeight(.semibold).foregroundStyle(DS.Colors.textPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .dsGlass(padding: DS.Spacing.lg)
        }
        .buttonStyle(.plain)
    }
}
