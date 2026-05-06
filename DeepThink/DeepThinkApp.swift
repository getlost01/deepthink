import SwiftUI
import SwiftData
import UserNotifications

private class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    weak var appState: AppState?
    var modelContainer: ModelContainer?

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let reminderIDString = response.notification.request.identifier
        guard let reminderID = UUID(uuidString: reminderIDString) else { return }

        await MainActor.run {
            if response.actionIdentifier == "ACKNOWLEDGE" {
                markCompleted(reminderID: reminderID)
            }
            appState?.navigateToReminder(reminderID)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    @MainActor
    private func markCompleted(reminderID: UUID) {
        guard let container = modelContainer else { return }
        let context = container.mainContext
        let descriptor = FetchDescriptor<Reminder>(predicate: #Predicate { $0.id == reminderID })
        guard let reminder = try? context.fetch(descriptor).first else { return }
        reminder.isCompleted = true
        reminder.completedAt = Date()
        reminder.modifiedAt = Date()
        reminder.notificationScheduled = false
        try? context.save()
    }

    static func registerCategories() {
        let acknowledge = UNNotificationAction(
            identifier: "ACKNOWLEDGE",
            title: "Acknowledge",
            options: [.foreground]
        )
        let category = UNNotificationCategory(
            identifier: "REMINDER",
            actions: [acknowledge],
            intentIdentifiers: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }
}

@main
struct DeepThinkApp: App {
    @State private var appState = AppState()
    @State private var commandPaletteState = CommandPaletteState()
    private let notificationDelegate = NotificationDelegate()

    var sharedModelContainer: ModelContainer = {
        StorageService.shared.ensureDirectoryStructure()

        let schema = Schema([Note.self, TaskItem.self, Project.self, Tag.self, NoteVersion.self, NoteLink.self, MCPServer.self, DataSource.self, Conversation.self, ChatMessage.self, Reminder.self])
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
                .handlesExternalEvents(preferring: ["main"], allowing: ["main"])
                .onAppear {
                    notificationDelegate.appState = appState
                    notificationDelegate.modelContainer = sharedModelContainer
                    NotificationDelegate.registerCategories()
                    let center = UNUserNotificationCenter.current()
                    center.delegate = notificationDelegate
                    center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
                    UserDefaults.standard.set("WhenScrolling", forKey: "AppleShowScrollBars")
                    registerCommands()
                    installCLI()
                    installDefaultMCPServers(container: sharedModelContainer)
                    SkillFileService.shared.installDefaultSkills()
                    RuleFileService.shared.installDefaultRules()
                    AgentFileService.shared.installDefaultAgents()
                    KnowledgeService.shared.reload()
                    CollectorScheduler.shared.start(container: sharedModelContainer)

                    // Register global hotkey for Quick Capture (Option+Space)
                    GlobalHotKey.shared.register(container: sharedModelContainer)
                }
        }
        .handlesExternalEvents(matching: ["main"])
        .modelContainer(sharedModelContainer)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Quick Capture  (\u{2325}Space)") {
                    QuickCaptureWindowController.shared.toggle(with: sharedModelContainer)
                }

                Divider()

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

                Button("New Reminder") {
                    appState.selectedSection = .reminders
                    NotificationCenter.default.post(name: .createNewReminder, object: nil)
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])

            }

            CommandGroup(after: .toolbar) {
                Button("Command Palette") {
                    appState.toggleCommandPalette()
                }
                .keyboardShortcut("k", modifiers: .command)

                Divider()

                Button("Go to Recent") {
                    appState.navigate(to: .recent)
                }
                .keyboardShortcut("0", modifiers: .command)

                Button("Go to Workspace") {
                    appState.navigate(to: .workspace)
                }
                .keyboardShortcut("1", modifiers: .command)

                Button("Go to Knowledge") {
                    appState.navigate(to: .knowledge)
                }
                .keyboardShortcut("2", modifiers: .command)

                Button("Go to AI Assistant") {
                    appState.navigate(to: .aiAssistant)
                }
                .keyboardShortcut("3", modifiers: .command)

                Button("Go to Integration") {
                    appState.navigate(to: .integrations)
                }
                .keyboardShortcut("4", modifiers: .command)

                Button("Go to Reminders") {
                    appState.navigate(to: .reminders)
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

                Button("Notes Tab") {
                    appState.selectedSection = .workspace
                    appState.workspaceTab = .notes
                }
                .keyboardShortcut("2", modifiers: [.command, .shift])

                Button("Tasks Tab") {
                    appState.selectedSection = .workspace
                    appState.workspaceTab = .tasks
                }
                .keyboardShortcut("3", modifiers: [.command, .shift])
            }
        }
        .defaultSize(width: 1200, height: 800)
    }

    private func registerCommands() {
        let state = appState
        let skillCommands = SkillFileService.shared.skills.map { skill in
            Command(title: "Run: \(skill.name)", icon: skill.icon, shortcut: nil, section: "Skills") {
                state.navigate(to: .aiAssistant)
                state.pendingSkillExecution = skill
            }
        }

        commandPaletteState.registerCommands(skillCommands + [
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
            Command(title: "New Reminder", icon: "bell.badge.fill", shortcut: "⇧⌘R", section: "Create") {
                appState.selectedSection = .reminders
                NotificationCenter.default.post(name: .createNewReminder, object: nil)
            },
            Command(title: "Quick Capture", icon: "bolt.fill", shortcut: "⌥Space", section: "Create") {
                QuickCaptureWindowController.shared.toggle(with: sharedModelContainer)
            },

            // Navigate
            Command(title: "Recent", icon: "clock.arrow.circlepath", shortcut: "⌘0", section: "Navigate") {
                appState.navigate(to: .recent)
            },
            Command(title: "Workspace", icon: "square.grid.2x2", shortcut: "⌘1", section: "Navigate") {
                appState.navigate(to: .workspace)
            },
            Command(title: "Projects", icon: "folder", shortcut: "⇧⌘1", section: "Navigate") {
                appState.selectedSection = .workspace
                appState.workspaceTab = .projects
            },
            Command(title: "All Notes", icon: "doc.text", shortcut: "⇧⌘2", section: "Navigate") {
                appState.selectedSection = .workspace
                appState.workspaceTab = .notes
            },
            Command(title: "All Tasks", icon: "checklist", shortcut: "⇧⌘3", section: "Navigate") {
                appState.selectedSection = .workspace
                appState.workspaceTab = .tasks
            },
            Command(title: "Knowledge", icon: "brain", shortcut: "⌘2", section: "Navigate") {
                appState.navigate(to: .knowledge)
            },
            Command(title: "AI Assistant", icon: "message.and.waveform", shortcut: "⌘3", section: "Navigate") {
                appState.navigate(to: .aiAssistant)
            },
            Command(title: "Integration", icon: "cable.connector", shortcut: "⌘4", section: "Navigate") {
                appState.navigate(to: .integrations)
            },
            Command(title: "Reminders", icon: "bell", shortcut: "⌘5", section: "Navigate") {
                appState.navigate(to: .reminders)
            },
            Command(title: "Assistants", icon: "person.2.circle", shortcut: nil, section: "Navigate") {
                appState.agentConfigTab = .agents
                appState.navigate(to: .integrations)
            },
            Command(title: "Skills", icon: "sparkles", shortcut: nil, section: "Navigate") {
                appState.agentConfigTab = .skills
                appState.navigate(to: .integrations)
            },
            Command(title: "Rules", icon: "bolt", shortcut: nil, section: "Navigate") {
                appState.agentConfigTab = .rules
                appState.navigate(to: .integrations)
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
                let core = MCPServer(
                    name: "DeepThink Workspace",
                    command: DeepThinkPaths.mcpBinaryPath,
                    args: "",
                    category: "Workspace",
                    description: "Core integration — manages tasks, notes, and projects in your DeepThink workspace",
                    isCore: true
                )
                context.insert(core)

                let defaults: [(String, String, String, String, String)] = [
                    ("Web Search", "npx", "-y @anthropic-ai/mcp-server-fetch", "Search",
                     "Fetch and read web pages — capture articles, docs, and research into your knowledge base"),
                    ("Filesystem", "npx", "-y @modelcontextprotocol/server-filesystem ~/Documents ~/Desktop", "Files",
                     "Read and search local files — import documents, notes, and data from your filesystem"),
                    ("Memory", "npx", "-y @modelcontextprotocol/server-memory", "Knowledge",
                     "Persistent memory for AI — remembers context across conversations"),
                ]

                for (name, command, args, category, desc) in defaults {
                    if !existing.contains(where: { $0.name == name }) {
                        let server = MCPServer(name: name, command: command, args: args, category: category, description: desc)
                        context.insert(server)
                    }
                }

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
            Self.installMCPConfig(fm: fm, mcpBinaryPath: installDir + "/deepthink-mcp")
        }
    }

    private static func installMCPConfig(fm: FileManager, mcpBinaryPath: String) {
        let mcpConfigPath = StorageService.shared.baseURL.appendingPathComponent(".mcp.json")

        let config: [String: Any] = [
            "mcpServers": [
                "deepthink": [
                    "command": mcpBinaryPath,
                    "args": [] as [String]
                ]
            ]
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: config, options: .prettyPrinted) else { return }
        try? data.write(to: mcpConfigPath)
        StorageService.shared.writeLog("MCP config installed: \(mcpConfigPath.path)", to: "app")

        registerGlobalMCP(mcpBinaryPath: mcpBinaryPath)
    }

    private static func registerGlobalMCP(mcpBinaryPath: String) {
        guard let claudePath = [
            DeepThinkPaths.localBin + "/claude",
            "/usr/local/bin/claude",
            "/opt/homebrew/bin/claude"
        ].first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else { return }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: claudePath)
        process.arguments = ["mcp", "add", "--transport", "stdio", "--scope", "user", "deepthink", "--", mcpBinaryPath]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()

        if process.terminationStatus == 0 {
            StorageService.shared.writeLog("MCP registered globally via claude CLI", to: "app")
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
    static let createNewReminder = Notification.Name("createNewReminder")
    static let quickCaptureReset = Notification.Name("quickCaptureReset")
}
