import SwiftUI
import SwiftData

struct ToolsHubView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MCPServer.name) private var servers: [MCPServer]
    @State private var showAddSheet = false
    @State private var showPresets = false
    @State private var selectedServer: MCPServer?
    @State private var testResult: String?
    @State private var isTesting = false

    private let categories = ["All", "Search", "Files", "Data", "Dev", "Web", "Knowledge", "Communication", "Project Management", "General"]

    @State private var selectedCategory = "All"

    private var filteredServers: [MCPServer] {
        if selectedCategory == "All" { return servers }
        return servers.filter { $0.category == selectedCategory }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: DS.Spacing.sm) {
                Spacer()

                Text("\(servers.filter(\.isEnabled).count) active")
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Colors.textSecondary)

                Button {
                    showPresets = true
                } label: {
                    Text("Presets")
                        .font(DS.Font.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    importFromClaude()
                } label: {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "square.and.arrow.down")
                        Text("Import")
                    }
                    .font(DS.Font.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Import MCP servers from Claude config")

                Button {
                    showAddSheet = true
                } label: {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "plus")
                        Text("Add")
                    }
                    .font(DS.Font.caption)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.vertical, DS.Spacing.md)
            .background(.bar)

            Divider()

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Spacing.xs) {
                    ForEach(categories, id: \.self) { cat in
                        Button {
                            selectedCategory = cat
                        } label: {
                            Text(cat)
                                .font(DS.Font.caption)
                                .fontWeight(selectedCategory == cat ? .medium : .regular)
                                .foregroundStyle(selectedCategory == cat ? DS.Colors.textPrimary : DS.Colors.textSecondary)
                                .padding(.horizontal, DS.Spacing.sm)
                                .padding(.vertical, DS.Spacing.xs)
                                .background(selectedCategory == cat ? DS.Colors.selectedBg : .clear, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.vertical, DS.Spacing.sm)
            }

            if filteredServers.isEmpty {
                DSEmptyState(
                    icon: "wrench.and.screwdriver",
                    title: "No Tools Configured",
                    subtitle: "MCP servers extend AI with web search, databases, file access, and more. Start with a preset or add your own.",
                    action: { showPresets = true },
                    actionTitle: "Browse Presets"
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 280, maximum: 400), spacing: DS.Spacing.md)], spacing: DS.Spacing.md) {
                        ForEach(filteredServers) { server in
                            ToolCard(server: server, onTest: { testServer(server) }, onDelete: { deleteServer(server) })
                        }
                    }
                    .padding(DS.Spacing.xl)
                }
            }

            if let testResult {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: isTesting ? "hourglass" : "checkmark.circle")
                        .foregroundStyle(isTesting ? DS.Colors.warning : DS.Colors.success)
                    Text(testResult)
                        .font(DS.Font.caption)
                        .lineLimit(1)
                    Spacer()
                    Button("Dismiss") { self.testResult = nil }
                        .font(DS.Font.caption)
                        .buttonStyle(.plain)
                }
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.vertical, DS.Spacing.sm)
                .background(.bar)
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddServerSheet { server in
                modelContext.insert(server)
            }
        }
        .sheet(isPresented: $showPresets) {
            PresetServersSheet { server in
                modelContext.insert(server)
            }
        }
    }

    private func testServer(_ server: MCPServer) {
        isTesting = true
        testResult = "Testing \(server.name)..."

        Task {
            do {
                let result = try await MCPService.shared.queryWithMCP(
                    prompt: "Test: confirm you can access the \(server.name) MCP server. Reply with a one-line confirmation.",
                    servers: [server]
                )
                await MainActor.run {
                    testResult = "✓ \(server.name): \(result.prefix(100))"
                    isTesting = false
                }
            } catch {
                await MainActor.run {
                    testResult = "✗ \(server.name): \(error.localizedDescription)"
                    isTesting = false
                }
            }
        }
    }

    private func deleteServer(_ server: MCPServer) {
        modelContext.delete(server)
    }

    private func importFromClaude() {
        let discovered = MCPService.shared.discoverFromClaudeConfig()
        let existingNames = Set(servers.map(\.name))
        var imported = 0

        for item in discovered {
            guard !existingNames.contains(item.name) else { continue }
            let server = MCPServer(
                name: item.name,
                command: item.command,
                args: item.args,
                category: item.category,
                description: item.description
            )
            modelContext.insert(server)
            imported += 1
        }

        if imported > 0 {
            testResult = "Imported \(imported) server(s) from Claude config"
        } else if discovered.isEmpty {
            testResult = "No Claude config found at ~/.claude.json"
        } else {
            testResult = "All discovered servers already exist"
        }
    }
}

private struct ToolCard: View {
    @Bindable var server: MCPServer
    let onTest: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: iconFor(server.category))
                    .font(.system(size: DS.IconSize.md, weight: .medium))
                    .foregroundStyle(DS.Colors.accent)
                    .frame(width: 28, height: 28)
                    .background(DS.Colors.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: DS.Radius.sm))

                VStack(alignment: .leading, spacing: 2) {
                    Text(server.name)
                        .font(DS.Font.body)
                        .fontWeight(.medium)
                    Text(server.category)
                        .font(DS.Font.tiny)
                        .foregroundStyle(DS.Colors.textSecondary)
                }

                Spacer()

                Toggle("", isOn: $server.isEnabled)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
            }

            if !server.serverDescription.isEmpty {
                Text(server.serverDescription)
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Colors.textSecondary)
                    .lineLimit(2)
            }

            Text(server.command + " " + server.args)
                .font(DS.Font.monoSmall)
                .foregroundStyle(DS.Colors.textTertiary)
                .lineLimit(1)

            HStack(spacing: DS.Spacing.sm) {
                Button("Test", action: onTest)
                    .font(DS.Font.tiny)
                    .buttonStyle(.bordered)
                    .controlSize(.mini)

                Spacer()

                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .font(DS.Font.tiny)
                }
                .buttonStyle(.plain)
                .foregroundStyle(DS.Colors.error.opacity(0.5))
            }
        }
        .padding(DS.Spacing.md)
        .dsClickable()
    }

    private func iconFor(_ category: String) -> String {
        switch category {
        case "Search": return "magnifyingglass"
        case "Files": return "folder"
        case "Data": return "cylinder"
        case "Dev": return "chevron.left.forwardslash.chevron.right"
        case "Web": return "globe"
        case "Knowledge": return "brain"
        case "Communication": return "message"
        case "Project Management": return "list.bullet.rectangle"
        default: return "wrench"
        }
    }
}

private struct AddServerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var command = ""
    @State private var args = ""
    @State private var envVars = ""
    @State private var category = "General"
    @State private var description = ""
    let onAdd: (MCPServer) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Add MCP Server")
                    .font(DS.Font.heading)
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
            }
            .padding(DS.Spacing.lg)

            Divider()

            Form {
                TextField("Name", text: $name)
                TextField("Command", text: $command)
                    .font(DS.Font.mono)
                TextField("Arguments", text: $args)
                    .font(DS.Font.mono)
                TextField("Category", text: $category)
                TextField("Description", text: $description)
                TextField("Environment Variables (KEY=VALUE per line)", text: $envVars, axis: .vertical)
                    .lineLimit(3...6)
                    .font(DS.Font.mono)
            }
            .padding(DS.Spacing.lg)

            Divider()

            HStack {
                Spacer()
                Button("Add Server") {
                    let server = MCPServer(name: name, command: command, args: args, envVars: envVars, category: category, description: description)
                    onAdd(server)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty || command.isEmpty)
            }
            .padding(DS.Spacing.lg)
        }
        .frame(width: 480, height: 440)
    }
}

private struct PresetServersSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onAdd: (MCPServer) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("MCP Server Presets")
                    .font(DS.Font.heading)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.plain)
            }
            .padding(DS.Spacing.lg)

            Divider()

            ScrollView {
                VStack(spacing: DS.Spacing.sm) {
                    ForEach(MCPService.presetServers, id: \.name) { preset in
                        HStack(spacing: DS.Spacing.md) {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: DS.Spacing.sm) {
                                    Text(preset.name)
                                        .font(DS.Font.body)
                                        .fontWeight(.medium)
                                    Text(preset.category)
                                        .font(DS.Font.tiny)
                                        .foregroundStyle(DS.Colors.textSecondary)
                                }
                                Text(preset.description)
                                    .font(DS.Font.caption)
                                    .foregroundStyle(DS.Colors.textSecondary)
                                Text("\(preset.command) \(preset.args)")
                                    .font(DS.Font.monoSmall)
                                    .foregroundStyle(DS.Colors.textTertiary)
                            }

                            Spacer()

                            Button("Add") {
                                let server = MCPServer(
                                    name: preset.name,
                                    command: preset.command,
                                    args: preset.args,
                                    category: preset.category,
                                    description: preset.description
                                )
                                onAdd(server)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        .padding(DS.Spacing.md)
                        .dsClickable()
                    }
                }
                .padding(DS.Spacing.lg)
            }
        }
        .frame(width: 560, height: 480)
    }
}
