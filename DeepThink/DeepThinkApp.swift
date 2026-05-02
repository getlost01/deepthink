import SwiftUI
import SwiftData

@main
struct DeepThinkApp: App {
    @State private var appState = AppState()
    @State private var commandPaletteState = CommandPaletteState()

    var sharedModelContainer: ModelContainer = {
        StorageService.shared.ensureDirectoryStructure()

        let schema = Schema([Note.self, TaskItem.self, Project.self, Tag.self, NoteVersion.self, NoteLink.self, MCPServer.self])
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

                Button("Go to Terminal") {
                    appState.navigate(to: .terminal)
                }
                .keyboardShortcut("3", modifiers: .command)

                Button("Go to Docs") {
                    appState.navigate(to: .docs)
                }
                .keyboardShortcut("4", modifiers: .command)

                Button("Go to Settings") {
                    appState.navigate(to: .settings)
                }
                .keyboardShortcut(",", modifiers: .command)

                Divider()

                Button("Projects Tab") {
                    appState.selectedSection = .workspace
                    appState.workspaceTab = .projects
                }
                .keyboardShortcut("1", modifiers: [.command, .shift])

                Button("Knowledge Base") {
                    appState.selectedSection = .workspace
                    appState.workspaceTab = .knowledge
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
            Command(title: "Projects", icon: "folder", shortcut: "⇧⌘1", section: "Navigate") {
                appState.selectedSection = .workspace
                appState.workspaceTab = .projects
            },
            Command(title: "Knowledge Base", icon: "brain", shortcut: "⇧⌘2", section: "Navigate") {
                appState.selectedSection = .workspace
                appState.workspaceTab = .knowledge
            },
            Command(title: "AI Chat", icon: "sparkles", shortcut: "⌘2", section: "Navigate") {
                appState.selectedSection = .ai
                appState.aiMode = .chat
            },
            Command(title: "AI Search", icon: "sparkle.magnifyingglass", shortcut: "⇧⌘F", section: "Navigate") {
                appState.selectedSection = .ai
                appState.aiMode = .search
            },
            Command(title: "AI Analyze", icon: "wand.and.rays", shortcut: nil, section: "Navigate") {
                appState.selectedSection = .ai
                appState.aiMode = .analyze
            },
            Command(title: "Terminal", icon: "terminal", shortcut: "⌘3", section: "Navigate") {
                appState.navigate(to: .terminal)
            },
            Command(title: "Docs", icon: "doc.text.magnifyingglass", shortcut: "⌘4", section: "Navigate") {
                appState.navigate(to: .docs)
            },
            Command(title: "Settings", icon: "gearshape", shortcut: "⌘,", section: "Navigate") {
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
                let mcpPath = NSHomeDirectory() + "/code/deepthink/cli/src/mcp-server.ts"
                let server = MCPServer(
                    name: "DeepThink Workspace",
                    command: "bun",
                    args: "run \(mcpPath)",
                    category: "Workspace",
                    description: "Manage tasks, notes, and projects in your DeepThink workspace"
                )
                context.insert(server)
                try? context.save()
            }
        }
    }

    private func installCLI() {
        DispatchQueue.global(qos: .utility).async {
            let fm = FileManager.default
            let installDir = NSHomeDirectory() + "/.local/bin"
            let installPath = installDir + "/deepthink"

            var sourcePath: String?
            if let bundled = Bundle.main.resourceURL?.appendingPathComponent("deepthink-cli").path,
               fm.isExecutableFile(atPath: bundled) {
                sourcePath = bundled
            } else {
                let devPaths = [
                    Bundle.main.bundlePath.components(separatedBy: "/DeepThink.app").first.map { $0 + "/cli/out/deepthink" },
                    NSHomeDirectory() + "/code/deepthink/cli/out/deepthink",
                    Bundle.main.bundlePath.components(separatedBy: "/DeepThink.app").first.map { $0 + "/cli/deepthink" },
                    NSHomeDirectory() + "/code/deepthink/cli/deepthink",
                ].compactMap { $0 }
                sourcePath = devPaths.first { fm.isExecutableFile(atPath: $0) }
            }

            guard let source = sourcePath else { return }

            if !fm.fileExists(atPath: installDir) {
                try? fm.createDirectory(atPath: installDir, withIntermediateDirectories: true)
            }

            try? fm.removeItem(atPath: installPath)
            try? fm.copyItem(atPath: source, toPath: installPath)
            try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: installPath)

            StorageService.shared.writeLog("CLI installed: \(installPath)", to: "app")
        }
    }
}

extension Notification.Name {
    static let createNewNote = Notification.Name("createNewNote")
    static let createNewTask = Notification.Name("createNewTask")
    static let createNewProject = Notification.Name("createNewProject")
}
