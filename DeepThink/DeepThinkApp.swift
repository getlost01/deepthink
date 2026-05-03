import SwiftUI
import SwiftData

@main
struct DeepThinkApp: App {
    @State private var appState = AppState()
    @State private var commandPaletteState = CommandPaletteState()

    var sharedModelContainer: ModelContainer = {
        StorageService.shared.ensureDirectoryStructure()

        let schema = Schema([Note.self, TaskItem.self, Project.self, Tag.self, NoteVersion.self, NoteLink.self, MCPServer.self, DataSource.self, Conversation.self, ChatMessage.self])
        let config = ModelConfiguration(
            schema: schema,
            url: StorageService.shared.storeURL,
            allowsSave: true
        )
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .environment(commandPaletteState)
                .frame(
                    minWidth: AppConstants.minWindowWidth,
                    minHeight: AppConstants.minWindowHeight
                )
                .onAppear {
                    registerCommands()
                    installCLI()
                    installDefaultMCPServers(container: sharedModelContainer)
                    SkillFileService.shared.installDefaultSkills()
                    RuleFileService.shared.installDefaultRules()
                    AgentFileService.shared.installDefaultAgents()
                    KnowledgeService.shared.reload()
                    CollectorScheduler.shared.start(container: sharedModelContainer)
                }
        }
        .modelContainer(sharedModelContainer)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Note") {
                    appState.selectedSection = .workspace
                    appState.workspaceTab = .projects
                    NotificationCenter.default.post(name: .createNewNote, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("New Task") {
                    appState.selectedSection = .workspace
                    appState.workspaceTab = .projects
                    NotificationCenter.default.post(name: .createNewTask, object: nil)
                }
                .keyboardShortcut("t", modifiers: .command)

                Button("New Project") {
                    appState.selectedSection = .workspace
                    appState.workspaceTab = .projects
                    NotificationCenter.default.post(name: .createNewProject, object: nil)
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            }

            CommandGroup(after: .toolbar) {
                Button("Command Palette") {
                    appState.toggleCommandPalette()
                }
                .keyboardShortcut("k", modifiers: .command)

                Divider()

                Button("Go to Workspace") {
                    appState.navigate(to: .workspace)
                }
                .keyboardShortcut("1", modifiers: .command)

                Button("Go to AI") {
                    appState.navigate(to: .ai)
                }
                .keyboardShortcut("2", modifiers: .command)

                Button("Go to Knowledge") {
                    appState.navigate(to: .knowledge)
                }
                .keyboardShortcut("3", modifiers: .command)

                Button("Go to Integrations") {
                    appState.navigate(to: .integrations)
                }
                .keyboardShortcut("4", modifiers: .command)

                Button("Go to Agent Config") {
                    appState.navigate(to: .agentConfig)
                }
                .keyboardShortcut("5", modifiers: .command)

                Button("Go to Terminal") {
                    appState.navigate(to: .terminal)
                }
                .keyboardShortcut("6", modifiers: .command)

                Divider()

                Button("Projects Tab") {
                    appState.selectedSection = .workspace
                    appState.workspaceTab = .projects
                }
                .keyboardShortcut("1", modifiers: [.command, .shift])

                Button("Knowledge") {
                    appState.navigate(to: .knowledge)
                }
                .keyboardShortcut("2", modifiers: [.command, .shift])
            }
        }
        .defaultSize(width: 1200, height: 800)
    }

    private func registerCommands() {
        commandPaletteState.registerCommands([
            // Create
            Command(title: "New Note", icon: "doc.text.badge.plus", shortcut: "⌘N", section: "Create") {
                appState.selectedSection = .workspace
                appState.workspaceTab = .projects
                NotificationCenter.default.post(name: .createNewNote, object: nil)
            },
            Command(title: "New Task", icon: "plus.circle", shortcut: "⌘T", section: "Create") {
                appState.selectedSection = .workspace
                appState.workspaceTab = .projects
                NotificationCenter.default.post(name: .createNewTask, object: nil)
            },
            Command(title: "New Project", icon: "folder.badge.plus", shortcut: "⇧⌘N", section: "Create") {
                appState.selectedSection = .workspace
                appState.workspaceTab = .projects
                NotificationCenter.default.post(name: .createNewProject, object: nil)
            },

            // Navigate
            Command(title: "Workspace", icon: "square.grid.2x2", shortcut: "⌘1", section: "Navigate") {
                appState.navigate(to: .workspace)
            },
            Command(title: "Overview", icon: "house", shortcut: "⇧⌘1", section: "Navigate") {
                appState.selectedSection = .workspace
                appState.workspaceTab = .overview
            },
            Command(title: "Projects", icon: "folder", shortcut: "⇧⌘2", section: "Navigate") {
                appState.selectedSection = .workspace
                appState.workspaceTab = .projects
            },
            Command(title: "All Notes", icon: "doc.text", shortcut: "⇧⌘3", section: "Navigate") {
                appState.selectedSection = .workspace
                appState.workspaceTab = .notes
            },
            Command(title: "All Tasks", icon: "checklist", shortcut: "⇧⌘4", section: "Navigate") {
                appState.selectedSection = .workspace
                appState.workspaceTab = .tasks
            },
            Command(title: "AI Chat", icon: "sparkles", shortcut: "⌘2", section: "Navigate") {
                appState.navigate(to: .ai)
            },
            Command(title: "Knowledge", icon: "brain", shortcut: "⌘3", section: "Navigate") {
                appState.navigate(to: .knowledge)
            },
            Command(title: "Integrations", icon: "puzzlepiece.extension", shortcut: "⌘4", section: "Navigate") {
                appState.navigate(to: .integrations)
            },
            Command(title: "Agent Config", icon: "person.2.circle", shortcut: "⌘5", section: "Navigate") {
                appState.navigate(to: .agentConfig)
            },
            Command(title: "Agents", icon: "person.2.circle", shortcut: "⇧⌘7", section: "Navigate") {
                appState.selectedSection = .agentConfig
                appState.agentConfigTab = .agents
            },
            Command(title: "Skills & Rules", icon: "sparkles", shortcut: "⇧⌘8", section: "Navigate") {
                appState.selectedSection = .agentConfig
                appState.agentConfigTab = .skillsAndRules
            },
            Command(title: "Terminal", icon: "terminal", shortcut: "⌘6", section: "Navigate") {
                appState.navigate(to: .terminal)
            },
            Command(title: "Settings", icon: "gear", shortcut: "⌘,", section: "Navigate") {
                appState.navigate(to: .settings)
            },
        ])
    }

    private func installDefaultMCPServers(container: ModelContainer) {
        DispatchQueue.global(qos: .utility).async {
            let context = ModelContext(container)
            let descriptor = FetchDescriptor<MCPServer>()
            let existing = (try? context.fetch(descriptor)) ?? []

            let hasWorkspace = existing.contains { $0.name == "DeepThink Workspace" }
            if !hasWorkspace {
                let server = MCPServer(
                    name: "DeepThink Workspace",
                    command: DeepThinkPaths.mcpBinaryPath,
                    args: "",
                    category: "Workspace",
                    description: "Core integration — manages tasks, notes, and projects in your DeepThink workspace",
                    isCore: true
                )
                context.insert(server)
                try? context.save()
            } else {
                for server in existing where server.name == "DeepThink Workspace" && !server.isCore {
                    server.isCore = true
                }
                try? context.save()
            }
        }
    }

    private func installCLI() {
        DispatchQueue.global(qos: .utility).async {
            let fm = FileManager.default
            let installDir = DeepThinkPaths.localBin

            if !fm.fileExists(atPath: installDir) {
                try? fm.createDirectory(atPath: installDir, withIntermediateDirectories: true)
            }

            Self.installBinary(named: "deepthink-cli", as: "deepthink", fm: fm, installDir: installDir)
            Self.installBinary(named: "deepthink-mcp", as: "deepthink-mcp", fm: fm, installDir: installDir)
        }
    }

    private static func installBinary(named bundleName: String, as installName: String, fm: FileManager, installDir: String) {
        let installPath = installDir + "/" + installName

        var sourcePath: String?
        if let bundled = Bundle.main.resourceURL?.appendingPathComponent(bundleName).path,
           fm.isExecutableFile(atPath: bundled) {
            sourcePath = bundled
        } else {
            let devCandidates = [
                Bundle.main.bundlePath.components(separatedBy: "/DeepThink.app").first.map { $0 + "/cli/out/" + installName },
                Bundle.main.bundlePath.components(separatedBy: "/DeepThink.app").first.map { $0 + "/cli/" + installName },
            ].compactMap { $0 }
            sourcePath = devCandidates.first { fm.isExecutableFile(atPath: $0) }
        }

        guard let source = sourcePath else { return }

        try? fm.removeItem(atPath: installPath)
        try? fm.copyItem(atPath: source, toPath: installPath)
        try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: installPath)

        StorageService.shared.writeLog("\(installName) installed: \(installPath)", to: "app")
    }
}

extension Notification.Name {
    static let createNewNote = Notification.Name("createNewNote")
    static let createNewTask = Notification.Name("createNewTask")
    static let createNewProject = Notification.Name("createNewProject")
}
