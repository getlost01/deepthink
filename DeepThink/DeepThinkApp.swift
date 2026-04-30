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
                }
        }
        .modelContainer(sharedModelContainer)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Note") {
                    appState.navigate(to: .notes)
                    NotificationCenter.default.post(name: .createNewNote, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("New Task") {
                    appState.navigate(to: .tasks)
                    NotificationCenter.default.post(name: .createNewTask, object: nil)
                }
                .keyboardShortcut("t", modifiers: .command)

                Button("New Project") {
                    appState.navigate(to: .projects)
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
            Command(title: "New Note", icon: "doc.text.badge.plus", shortcut: "⌘N", section: "Create") {
                appState.navigate(to: .notes)
                NotificationCenter.default.post(name: .createNewNote, object: nil)
            },
            Command(title: "New Task", icon: "plus.circle", shortcut: "⌘T", section: "Create") {
                appState.navigate(to: .tasks)
                NotificationCenter.default.post(name: .createNewTask, object: nil)
            },
            Command(title: "New Project", icon: "folder.badge.plus", shortcut: "⇧⌘N", section: "Create") {
                appState.navigate(to: .projects)
                NotificationCenter.default.post(name: .createNewProject, object: nil)
            },
            Command(title: "AI Chat", icon: "bubble.left.and.bubble.right", shortcut: nil, section: "Navigate") {
                appState.navigate(to: .chat)
            },
            Command(title: "Deep Search", icon: "sparkle.magnifyingglass", shortcut: "⇧⌘F", section: "Navigate") {
                appState.navigate(to: .deepSearch)
            },
            Command(title: "Analysis", icon: "wand.and.rays", shortcut: nil, section: "Navigate") {
                appState.navigate(to: .analysis)
            },
            Command(title: "Notes", icon: "doc.text", shortcut: nil, section: "Navigate") {
                appState.navigate(to: .notes)
            },
            Command(title: "Tasks", icon: "checklist", shortcut: nil, section: "Navigate") {
                appState.navigate(to: .tasks)
            },
            Command(title: "Projects", icon: "folder", shortcut: nil, section: "Navigate") {
                appState.navigate(to: .projects)
            },
            Command(title: "Tools & MCP", icon: "wrench.and.screwdriver", shortcut: nil, section: "Navigate") {
                appState.navigate(to: .tools)
            },
            Command(title: "Knowledge Graph", icon: "point.3.connected.trianglepath.dotted", shortcut: nil, section: "Navigate") {
                appState.navigate(to: .graph)
            },
            Command(title: "Terminal", icon: "terminal", shortcut: nil, section: "Navigate") {
                appState.navigate(to: .terminal)
            },
            Command(title: "Home", icon: "house", shortcut: nil, section: "Navigate") {
                appState.navigate(to: .home)
            },
        ])
    }
}

extension Notification.Name {
    static let createNewNote = Notification.Name("createNewNote")
    static let createNewTask = Notification.Name("createNewTask")
    static let createNewProject = Notification.Name("createNewProject")
}
