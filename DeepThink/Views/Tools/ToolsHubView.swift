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
                DSHelpButton(text: SidebarSection.integrations.helpText)

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
            .background(DS.Colors.surfaceElevated)

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
                                .background(selectedCategory == cat ? DS.Colors.accentFill : .clear, in: Capsule())
                        }
                        .buttonStyle(.plainPointer)
                    }
                }
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.vertical, DS.Spacing.sm)
            }

            if filteredServers.isEmpty {
                DSEmptyState(
                    icon: "wrench.and.screwdriver",
                    title: "No Connections Yet",
                    subtitle: "Connections give AI access to external tools like web search, file systems, and databases.",
                    hint: "Start with a preset to see what's possible",
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
                        .buttonStyle(.plainPointer)
                }
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.vertical, DS.Spacing.sm)
                .background(DS.Colors.surfaceElevated)
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
        .dsPage()
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
        guard !server.isCore else { return }
        modelContext.delete(server)
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
                        .font(DS.Font.small)
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
                if server.isCore {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 8))
                        Text("Core")
                            .font(DS.Font.small)
                    }
                    .foregroundStyle(DS.Colors.accent)
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, 2)
                    .background(DS.Colors.accentFill, in: Capsule())
                }

                Button("Test", action: onTest)
                    .font(DS.Font.small)
                    .buttonStyle(.bordered)
                    .controlSize(.mini)

                Spacer()

                if !server.isCore {
                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash")
                            .font(DS.Font.small)
                    }
                    .buttonStyle(.plainPointer)
                    .foregroundStyle(DS.Colors.danger.opacity(0.5))
                }
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

// MARK: - Add Server Sheet (redesigned)

private struct AddServerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var inputMode: InputMode = .form
    @State private var name = ""
    @State private var command = ""
    @State private var args = ""
    @State private var envVars = ""
    @State private var category = "General"
    @State private var description = ""
    @State private var extraFields: [ExtraField] = []
    @State private var jsonText = ""
    @State private var jsonError: String?
    let onAdd: (MCPServer) -> Void

    enum InputMode: String, CaseIterable {
        case form = "Form"
        case json = "JSON"
    }

    struct ExtraField: Identifiable {
        let id = UUID()
        var key: String = ""
        var value: String = ""
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Add MCP Server")
                    .font(DS.Font.heading)
                Spacer()

                Picker(selection: $inputMode) {
                    ForEach(InputMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                } label: { EmptyView() }
                .pickerStyle(.segmented)
                .frame(width: 140)

                Button("Cancel") { dismiss() }
                    .buttonStyle(.plainPointer)
                    .foregroundStyle(DS.Colors.textSecondary)
            }
            .padding(DS.Spacing.lg)
            .background(DS.Colors.surfaceElevated)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    if inputMode == .form {
                        formContent
                    } else {
                        jsonContent
                    }
                }
                .padding(DS.Spacing.lg)
            }

            Divider()

            HStack {
                Spacer()
                Button(action: addServer) {
                    Text("Add Server")
                        .font(DS.Font.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(DS.Colors.onAccent)
                        .padding(.horizontal, DS.Spacing.xl)
                        .padding(.vertical, DS.Spacing.sm)
                        .background(canAdd ? DS.Colors.accent : DS.Colors.accent.opacity(0.5), in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                }
                .buttonStyle(.plainPointer)
                .disabled(!canAdd)
            }
            .padding(DS.Spacing.lg)
        }
        .frame(width: 520, height: 520)
    }

    private var canAdd: Bool {
        if inputMode == .json {
            return !jsonText.isEmpty && jsonError == nil
        }
        return !name.isEmpty && !command.isEmpty
    }

    @ViewBuilder
    private var formContent: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            fieldRow(label: "Name", text: $name, placeholder: "My MCP Server")
            fieldRow(label: "Command", text: $command, placeholder: "npx -y @modelcontextprotocol/server-xxx", mono: true)
            fieldRow(label: "Arguments", text: $args, placeholder: "Optional arguments", mono: true)
            fieldRow(label: "Category", text: $category, placeholder: "General")
            fieldRow(label: "Description", text: $description, placeholder: "What does this server do?")

            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text("Environment Variables")
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Colors.textSecondary)
                TextField("KEY=VALUE (one per line)", text: $envVars, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(DS.Font.mono)
                    .lineLimit(2...4)
                    .dsInputField()
            }

            // Extra fields
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                HStack {
                    Text("Extra Fields")
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Colors.textSecondary)
                    Spacer()
                    Button {
                        extraFields.append(ExtraField())
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(DS.Colors.accent)
                    }
                    .buttonStyle(.plainPointer)
                }

                ForEach($extraFields) { $field in
                    HStack(spacing: DS.Spacing.sm) {
                        TextField("Key", text: $field.key)
                            .textFieldStyle(.plain)
                            .font(DS.Font.mono)
                            .dsInputField()
                            .frame(width: 120)
                        TextField("Value", text: $field.value)
                            .textFieldStyle(.plain)
                            .font(DS.Font.mono)
                            .dsInputField()
                        Button {
                            extraFields.removeAll { $0.id == field.id }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(DS.Colors.textTertiary)
                        }
                        .buttonStyle(.plainPointer)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var jsonContent: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Paste MCP server JSON configuration")
                .font(DS.Font.caption)
                .foregroundStyle(DS.Colors.textSecondary)

            TextEditor(text: $jsonText)
                .font(DS.Font.mono)
                .frame(minHeight: 200)
                .padding(DS.Spacing.sm)
                .background(DS.Colors.fillSecondary, in: RoundedRectangle(cornerRadius: DS.Radius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.md)
                        .strokeBorder(DS.Colors.border, lineWidth: 1)
                )
                .onChange(of: jsonText) { _, newValue in
                    validateJSON(newValue)
                }

            if let jsonError {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(DS.Colors.danger)
                    Text(jsonError)
                        .font(DS.Font.small)
                        .foregroundStyle(DS.Colors.danger)
                }
            }

            Text("Example: {\"command\": \"npx\", \"args\": \"-y @server/name\", \"env\": {\"API_KEY\": \"...\"}}")
                .font(DS.Font.small)
                .foregroundStyle(DS.Colors.textTertiary)
        }
    }

    @ViewBuilder
    private func fieldRow(label: String, text: Binding<String>, placeholder: String, mono: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(label)
                .font(DS.Font.caption)
                .foregroundStyle(DS.Colors.textSecondary)
            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .font(mono ? DS.Font.mono : DS.Font.body)
                .dsInputField()
        }
    }

    private func validateJSON(_ text: String) {
        guard !text.isEmpty else { jsonError = nil; return }
        guard let data = text.data(using: .utf8) else { jsonError = "Invalid text"; return }
        do {
            let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            if obj == nil { jsonError = "Must be a JSON object" } else { jsonError = nil }
        } catch {
            jsonError = error.localizedDescription
        }
    }

    private func addServer() {
        if inputMode == .json {
            addFromJSON()
        } else {
            let server = MCPServer(name: name, command: command, args: args, envVars: envVars, category: category, description: description)
            onAdd(server)
        }
        dismiss()
    }

    private func addFromJSON() {
        guard let data = jsonText.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

        let serverName = obj["name"] as? String ?? "Unnamed Server"
        let serverCommand = obj["command"] as? String ?? ""
        let serverArgs: String
        if let argsArray = obj["args"] as? [String] {
            serverArgs = argsArray.joined(separator: " ")
        } else {
            serverArgs = obj["args"] as? String ?? ""
        }

        var envString = ""
        if let env = obj["env"] as? [String: String] {
            envString = env.map { "\($0.key)=\($0.value)" }.joined(separator: "\n")
        }

        let serverCategory = obj["category"] as? String ?? "General"
        let serverDesc = obj["description"] as? String ?? ""

        let server = MCPServer(name: serverName, command: serverCommand, args: serverArgs, envVars: envString, category: serverCategory, description: serverDesc)
        onAdd(server)
    }
}

private struct PresetServersSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onAdd: (MCPServer) -> Void

    private let catalog = MCPCatalogService.shared

    @State private var searchText = ""
    @State private var selectedCategory = "All"
    @State private var addedNames: Set<String> = []

    private let categories = ["All", "Search", "Files", "Data", "Dev", "Web", "Knowledge", "Communication", "Project Management", "General"]

    private var filteredPackages: [MCPPackage] {
        var results = catalog.packages
        if selectedCategory != "All" {
            results = results.filter { $0.category == selectedCategory }
        }
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            results = results.filter {
                $0.name.lowercased().contains(q) ||
                $0.description.lowercased().contains(q) ||
                $0.displayName.lowercased().contains(q)
            }
        }
        return results
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: DS.Spacing.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("MCP Server Catalog")
                        .font(DS.Font.heading)
                    if let fetched = catalog.lastFetchedAt {
                        Text("Updated \(fetched.relativeFormatted)")
                            .font(DS.Font.small)
                            .foregroundStyle(DS.Colors.textTertiary)
                    }
                }
                Spacer()

                if catalog.isLoading {
                    ProgressView().controlSize(.small)
                }

                Button {
                    Task { await catalog.fetchCatalog() }
                } label: {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 9, weight: .semibold))
                        Text("Refresh")
                            .font(DS.Font.small)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("Done") { dismiss() }
                    .buttonStyle(.plainPointer)
                    .foregroundStyle(DS.Colors.textSecondary)
            }
            .padding(DS.Spacing.lg)
            .background(DS.Colors.surfaceElevated)

            Divider()

            DSSearchField(text: $searchText, placeholder: "Search MCP servers...")
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.sm)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Spacing.xs) {
                    ForEach(categories, id: \.self) { cat in
                        Button {
                            selectedCategory = cat
                        } label: {
                            Text(cat)
                                .font(DS.Font.small)
                                .foregroundStyle(selectedCategory == cat ? DS.Colors.onAccent : DS.Colors.textSecondary)
                                .padding(.horizontal, DS.Spacing.sm + 2)
                                .padding(.vertical, DS.Spacing.xs + 1)
                                .background(selectedCategory == cat ? DS.Colors.accent : DS.Colors.fill, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                        }
                        .buttonStyle(.plainPointer)
                    }

                    Spacer()

                    Text("\(filteredPackages.count) servers")
                        .font(DS.Font.small)
                        .foregroundStyle(DS.Colors.textTertiary)
                }
                .padding(.horizontal, DS.Spacing.lg)
            }
            .padding(.bottom, DS.Spacing.sm)

            Divider()

            if catalog.packages.isEmpty && !catalog.isLoading {
                DSEmptyState(
                    icon: "puzzlepiece.extension",
                    title: "No Catalog Data",
                    subtitle: "Tap Refresh to fetch MCP servers from npm registry.",
                    action: { Task { await catalog.fetchCatalog() } },
                    actionTitle: "Fetch Catalog"
                )
            } else if filteredPackages.isEmpty {
                DSEmptyState(
                    icon: "magnifyingglass",
                    title: "No Matches",
                    subtitle: "Try a different search or category."
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredPackages) { pkg in
                            CatalogRow(package: pkg, isAdded: addedNames.contains(pkg.name)) {
                                let server = MCPServer(
                                    name: pkg.displayName,
                                    command: pkg.installCommand,
                                    args: pkg.installArgs,
                                    category: pkg.category,
                                    description: pkg.description
                                )
                                onAdd(server)
                                addedNames.insert(pkg.name)
                            }

                            if pkg.id != filteredPackages.last?.id {
                                Divider().padding(.leading, 52)
                            }
                        }
                    }
                }
            }
        }
        .frame(width: 640, height: 560)
        .onAppear {
            if catalog.needsRefresh {
                Task { await catalog.fetchCatalog() }
            }
        }
    }
}

// MARK: - Catalog Row

private struct CatalogRow: View {
    let package: MCPPackage
    let isAdded: Bool
    let onAdd: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: DS.Radius.sm)
                    .fill(DS.Colors.accentFill)
                    .frame(width: 32, height: 32)
                Image(systemName: package.iconName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(DS.Colors.accent)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: DS.Spacing.sm) {
                    Text(package.displayName)
                        .font(DS.Font.body)
                        .fontWeight(.medium)

                    Text("v\(package.version)")
                        .font(DS.Font.small)
                        .foregroundStyle(DS.Colors.textTertiary)

                    DSPill(text: package.category, color: .blue)
                }

                if !package.description.isEmpty {
                    Text(package.description)
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Colors.textSecondary)
                        .lineLimit(1)
                }

                Text(package.name)
                    .font(DS.Font.monoSmall)
                    .foregroundStyle(DS.Colors.textTertiary)
                    .lineLimit(1)
            }

            Spacer()

            if !package.author.isEmpty {
                Text(package.author)
                    .font(DS.Font.small)
                    .foregroundStyle(DS.Colors.textTertiary)
            }

            if isAdded {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(DS.Colors.success)
            } else {
                Button("Add", action: onAdd)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm + 2)
        .background(isHovered ? DS.Colors.fillSecondary : .clear)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .animation(DS.Animation.quick, value: isHovered)
    }
}
