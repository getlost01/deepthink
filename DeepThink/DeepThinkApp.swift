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
                }
        }
        .modelContainer(sharedModelContainer)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Note") {
                    appState.selectedSection = .workspace
                    appState.workspaceTab = .notes
                    NotificationCenter.default.post(name: .createNewNote, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("New Task") {
                    appState.selectedSection = .workspace
                    appState.workspaceTab = .tasks
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
            }
        }
        .defaultSize(width: 1200, height: 800)
    }

    private func registerCommands() {
        commandPaletteState.registerCommands([
            // Create
            Command(title: "New Note", icon: "doc.text.badge.plus", shortcut: "⌘N", section: "Create") {
                appState.selectedSection = .workspace
                appState.workspaceTab = .notes
                NotificationCenter.default.post(name: .createNewNote, object: nil)
            },
            Command(title: "New Task", icon: "plus.circle", shortcut: "⌘T", section: "Create") {
                appState.selectedSection = .workspace
                appState.workspaceTab = .tasks
                NotificationCenter.default.post(name: .createNewTask, object: nil)
            },
            Command(title: "New Project", icon: "folder.badge.plus", shortcut: "⇧⌘N", section: "Create") {
                appState.selectedSection = .workspace
                appState.workspaceTab = .projects
                NotificationCenter.default.post(name: .createNewProject, object: nil)
            },

            // Navigate
            Command(title: "Workspace", icon: "square.grid.2x2", shortcut: nil, section: "Navigate") {
                appState.navigate(to: .workspace)
            },
            Command(title: "Notes", icon: "doc.text", shortcut: nil, section: "Navigate") {
                appState.selectedSection = .workspace
                appState.workspaceTab = .notes
            },
            Command(title: "Tasks", icon: "checklist", shortcut: nil, section: "Navigate") {
                appState.selectedSection = .workspace
                appState.workspaceTab = .tasks
            },
            Command(title: "Projects", icon: "folder", shortcut: nil, section: "Navigate") {
                appState.selectedSection = .workspace
                appState.workspaceTab = .projects
            },
            Command(title: "AI Chat", icon: "sparkles", shortcut: nil, section: "Navigate") {
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
            Command(title: "Terminal", icon: "terminal", shortcut: nil, section: "Navigate") {
                appState.navigate(to: .terminal)
            },
            Command(title: "Docs", icon: "doc.text.magnifyingglass", shortcut: nil, section: "Navigate") {
                appState.navigate(to: .docs)
            },
            Command(title: "Settings", icon: "gearshape", shortcut: nil, section: "Navigate") {
                appState.navigate(to: .settings)
            },
        ])
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
