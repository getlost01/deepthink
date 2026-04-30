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
            HStack(spacing: 12) {
                Image(systemName: "wrench.and.screwdriver")
                    .foregroundStyle(.indigo)
                Text("Tools & MCP Servers")
                    .font(.headline)

                Spacer()

                Text("\(servers.filter(\.isEnabled).count) active")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.green.opacity(0.1), in: Capsule())

                Button {
                    showPresets = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.square.on.square")
                        Text("Presets")
                    }
                    .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    showAddSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("Custom")
                    }
                    .font(.caption)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(.bar)

            Divider()

            HStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(categories, id: \.self) { cat in
                            Button {
                                selectedCategory = cat
                            } label: {
                                Text(cat)
                                    .font(.caption)
                                    .fontWeight(selectedCategory == cat ? .semibold : .regular)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(selectedCategory == cat ? Color.accentColor.opacity(0.15) : .clear, in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 8)
                }
            }
            .background(.bar.opacity(0.5))

            Divider()

            if filteredServers.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "wrench.and.screwdriver")
                        .font(.system(size: 36))
                        .foregroundStyle(.tertiary)
                    Text("No tools configured")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("Add MCP servers to give Claude superpowers — search the web, query databases, manage files, and more")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 400)
                    Button("Browse Presets") { showPresets = true }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 280, maximum: 400), spacing: 12)], spacing: 12) {
                        ForEach(filteredServers) { server in
                            ToolCard(server: server, onTest: { testServer(server) }, onDelete: { deleteServer(server) })
                        }
                    }
                    .padding(24)
                }
            }

            if let testResult {
                HStack(spacing: 8) {
                    Image(systemName: isTesting ? "hourglass" : "checkmark.circle")
                        .foregroundStyle(isTesting ? .orange : .green)
                    Text(testResult)
                        .font(.caption)
                        .lineLimit(1)
                    Spacer()
                    Button("Dismiss") { self.testResult = nil }
                        .font(.caption)
                        .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
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
}

private struct ToolCard: View {
    @Bindable var server: MCPServer
    let onTest: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: iconFor(server.category))
                    .font(.title3)
                    .foregroundStyle(.indigo)
                    .frame(width: 32, height: 32)
                    .background(.indigo.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(server.name)
                        .font(.callout)
                        .fontWeight(.semibold)
                    Text(server.category)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Toggle("", isOn: $server.isEnabled)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
            }

            if !server.serverDescription.isEmpty {
                Text(server.serverDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Text(server.command + " " + server.args)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.tertiary)
                .lineLimit(1)

            HStack(spacing: 8) {
                Button("Test", action: onTest)
                    .font(.caption2)
                    .buttonStyle(.bordered)
                    .controlSize(.mini)

                Spacer()

                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .font(.caption2)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red.opacity(0.6))
            }
        }
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(server.isEnabled ? Color.green.opacity(0.3) : Color.secondary.opacity(0.15))
        )
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
                Text("Add Custom MCP Server")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
            }
            .padding(16)

            Divider()

            Form {
                TextField("Name", text: $name)
                TextField("Command", text: $command)
                    .font(.system(.body, design: .monospaced))
                TextField("Arguments", text: $args)
                    .font(.system(.body, design: .monospaced))
                TextField("Category", text: $category)
                TextField("Description", text: $description)
                TextField("Environment Variables (KEY=VALUE per line)", text: $envVars, axis: .vertical)
                    .lineLimit(3...6)
                    .font(.system(.body, design: .monospaced))
            }
            .padding(16)

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
            .padding(16)
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
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.plain)
            }
            .padding(16)

            Divider()

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(MCPService.presetServers, id: \.name) { preset in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(preset.name).font(.callout).fontWeight(.medium)
                                    Text(preset.category)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(.quaternary, in: Capsule())
                                }
                                Text(preset.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("\(preset.command) \(preset.args)")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.tertiary)
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
                        .padding(12)
                        .background(.background, in: RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.quaternary.opacity(0.5)))
                    }
                }
                .padding(16)
            }
        }
        .frame(width: 600, height: 500)
    }
}
