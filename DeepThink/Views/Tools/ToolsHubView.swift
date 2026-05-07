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
            DSSectionBanner(
                icon: "puzzlepiece.extension",
                title: "MCP Servers",
                subtitle: "Connect external tools and services for AI to use",
                color: DS.Colors.teal
            )

            Divider()

            HStack(spacing: DS.Spacing.sm) {
                Text("\(servers.filter(\.isEnabled).count) active")
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Colors.textSecondary)

                Spacer()

                Button {
                    showPresets = true
                } label: {
                    Text("Presets")
                        .font(DS.Font.caption)
                }
                .buttonStyle(.dsSecondary)
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
                .buttonStyle(.dsPrimary)
                .controlSize(.small)
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.sm)
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
                .padding(.horizontal, DS.Spacing.lg)
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
                    .padding(DS.Spacing.lg)
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
                .padding(.horizontal, DS.Spacing.lg)
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
    @State private var showCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(alignment: .center, spacing: DS.Spacing.sm) {
                DSIconBadge(icon: iconFor(server.category), color: DS.Colors.textSecondary, background: DS.Colors.fill)

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(server.name)
                        .font(DS.Font.body)
                        .fontWeight(.medium)
                    Text(server.category)
                        .font(DS.Font.small)
                        .foregroundStyle(DS.Colors.textSecondary)
                }

                Spacer(minLength: DS.Spacing.sm)

                Toggle("", isOn: $server.isEnabled)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .labelsHidden()
                    .pointerOnHover()
                    .fixedSize()
            }

            if !server.serverDescription.isEmpty {
                Text(server.serverDescription)
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Colors.textSecondary)
                    .lineLimit(2)
            }

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(server.command + (server.args.isEmpty ? "" : " " + server.args), forType: .string)
                withAnimation(DS.Animation.quick) { showCopied = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation(DS.Animation.quick) { showCopied = false }
                }
            } label: {
                HStack(spacing: DS.Spacing.xs) {
                    Text(server.command + (server.args.isEmpty ? "" : " " + server.args))
                        .font(DS.Font.monoSmall)
                        .foregroundStyle(DS.Colors.textTertiary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: DS.IconSize.xs))
                        .foregroundStyle(showCopied ? DS.Colors.success : DS.Colors.textTertiary)
                }
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.vertical, DS.Spacing.xs)
                .background(DS.Colors.fillSecondary, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm).strokeBorder(DS.Colors.border, lineWidth: 1))
            }
            .buttonStyle(.plainPointer)

            HStack(spacing: DS.Spacing.sm) {
                Button("Test", action: onTest)
                    .font(DS.Font.small)
                    .buttonStyle(.dsSecondary)
                    .controlSize(.mini)

                if !server.isCore {
                    Button("Remove", action: onDelete)
                        .font(DS.Font.small)
                        .buttonStyle(.dsSecondary)
                        .controlSize(.mini)
                        .foregroundStyle(DS.Colors.danger)
                }

                Spacer()

                if server.isCore {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: DS.IconSize.xs))
                        Text("Core")
                            .font(DS.Font.micro)
                    }
                    .foregroundStyle(DS.Colors.accent)
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, DS.Spacing.xxs)
                    .background(DS.Colors.accentFill, in: Capsule())
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
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

// MARK: - Add Server Sheet

private struct AddServerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var inputMode: InputMode = .form
    @State private var name = ""
    @State private var command = ""
    @State private var args = ""
    @State private var envVars = ""
    @State private var category = "General"
    @State private var description = ""
    @State private var jsonText = ""
    @State private var jsonError: String?
    let onAdd: (MCPServer) -> Void

    private let categories = ["General", "Search", "Files", "Data", "Dev", "Web", "Knowledge", "Communication", "Project Management"]

    enum InputMode: String, CaseIterable {
        case form = "Form"
        case json = "JSON"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: DS.Spacing.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Add MCP Server")
                        .font(DS.Font.heading)
                    Text("Connect a tool for AI to use")
                        .font(DS.Font.small)
                        .foregroundStyle(DS.Colors.textTertiary)
                }
                Spacer()
                HStack(spacing: 0) {
                    ForEach(InputMode.allCases, id: \.self) { mode in
                        Button {
                            withAnimation(DS.Animation.quick) { inputMode = mode }
                        } label: {
                            Text(mode.rawValue)
                                .font(DS.Font.small)
                                .fontWeight(.medium)
                                .foregroundStyle(inputMode == mode ? DS.Colors.accent : DS.Colors.textTertiary)
                                .padding(.horizontal, DS.Spacing.md)
                                .padding(.vertical, DS.Spacing.xs + 2)
                                .background(inputMode == mode ? DS.Colors.accentFill : .clear, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                        }
                        .buttonStyle(.plainPointer)
                    }
                }
                .padding(2)
                .background(DS.Colors.fill, in: RoundedRectangle(cornerRadius: DS.Radius.sm + 2))

                Button("Cancel") { dismiss() }
                    .buttonStyle(.plainPointer)
                    .foregroundStyle(DS.Colors.textSecondary)
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)
            .background(DS.Colors.surfaceElevated)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    if inputMode == .form { formContent } else { jsonContent }
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
                        .background(
                            canAdd ? DS.Colors.accent : DS.Colors.accent.opacity(DS.Opacity.disabled),
                            in: RoundedRectangle(cornerRadius: DS.Radius.sm)
                        )
                }
                .buttonStyle(.plainPointer)
                .disabled(!canAdd)
            }
            .padding(DS.Spacing.lg)
        }
        .frame(width: 520)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var canAdd: Bool {
        inputMode == .json ? (!jsonText.isEmpty && jsonError == nil) : (!name.isEmpty && !command.isEmpty)
    }

    @ViewBuilder
    private var formContent: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            DSLabeledTextField(label: "Name *", text: $name, placeholder: "My MCP Server")

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text("Category")
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Colors.textSecondary)
                Picker("Category", selection: $category) {
                    ForEach(categories, id: \.self) { cat in
                        Text(cat).tag(cat)
                    }
                }
                .pickerStyle(.menu)
                .font(DS.Font.body)
                .fixedSize()
                .onHover { if $0 { NSCursor.pointingHand.push() } else { NSCursor.pop() } }
            }

            DSLabeledTextField(label: "Description", text: $description, placeholder: "What does this server do?")

            Divider()

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text("Command *")
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Colors.textSecondary)
                TextField("npx", text: $command)
                    .textFieldStyle(.plain)
                    .font(DS.Font.monoSmall)
                    .dsInputField()
            }

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text("Arguments")
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Colors.textSecondary)
                TextField("-y @modelcontextprotocol/server-xxx", text: $args)
                    .textFieldStyle(.plain)
                    .font(DS.Font.monoSmall)
                    .dsInputField()
            }

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text("Environment Variables")
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Colors.textSecondary)
                Text("One per line: KEY=VALUE")
                    .font(DS.Font.small)
                    .foregroundStyle(DS.Colors.textTertiary)
                TextField("API_KEY=abc123", text: $envVars, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(DS.Font.monoSmall)
                    .lineLimit(2...4)
                    .dsInputField()
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
                .font(DS.Font.monoSmall)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 200)
                .padding(DS.Spacing.sm)
                .background(DS.Colors.fillSecondary, in: RoundedRectangle(cornerRadius: DS.Radius.md))
                .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).strokeBorder(DS.Colors.border, lineWidth: 1))
                .onChange(of: jsonText) { _, v in validateJSON(v) }

            if let jsonError {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: DS.IconSize.xs))
                        .foregroundStyle(DS.Colors.danger)
                    Text(jsonError)
                        .font(DS.Font.small)
                        .foregroundStyle(DS.Colors.danger)
                }
            }

            Text(#"Example: {"command": "npx", "args": ["-y", "@server/name"], "env": {"API_KEY": "..."}}"#)
                .font(DS.Font.small)
                .foregroundStyle(DS.Colors.textTertiary)
        }
    }

    private func validateJSON(_ text: String) {
        guard !text.isEmpty else { jsonError = nil; return }
        guard let data = text.data(using: .utf8) else { jsonError = "Invalid text"; return }
        do {
            let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            jsonError = obj == nil ? "Must be a JSON object" : nil
        } catch {
            jsonError = error.localizedDescription
        }
    }

    private func addServer() {
        if inputMode == .json {
            addFromJSON()
        } else {
            onAdd(MCPServer(name: name, command: command, args: args, envVars: envVars, category: category, description: description))
        }
        dismiss()
    }

    private func addFromJSON() {
        guard let data = jsonText.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

        let serverArgs: String
        if let arr = obj["args"] as? [String] { serverArgs = arr.joined(separator: " ") }
        else { serverArgs = obj["args"] as? String ?? "" }

        var envString = ""
        if let env = obj["env"] as? [String: String] {
            envString = env.map { "\($0.key)=\($0.value)" }.joined(separator: "\n")
        }

        onAdd(MCPServer(
            name: obj["name"] as? String ?? "Unnamed Server",
            command: obj["command"] as? String ?? "",
            args: serverArgs,
            envVars: envString,
            category: obj["category"] as? String ?? "General",
            description: obj["description"] as? String ?? ""
        ))
    }
}

private struct PresetServersSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onAdd: (MCPServer) -> Void

    private let catalog = MCPCatalogService.shared

    @State private var searchText = ""
    @State private var selectedCategory = "All"
    @State private var addedNames: Set<String> = []
    @State private var liveResults: [MCPPackage] = []
    @State private var isSearching = false
    @State private var liveFrom = 0
    @State private var hasMore = false

    private let categories = ["All", "Search", "Files", "Data", "Dev", "Web", "Knowledge", "Communication", "Project Management", "General"]

    private var isLiveSearch: Bool { !searchText.isEmpty }

    private var filteredPackages: [MCPPackage] {
        if isLiveSearch { return liveResults }
        var results = catalog.packages
        if selectedCategory != "All" {
            results = results.filter { $0.category == selectedCategory }
        }
        return results
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: DS.Spacing.md) {
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
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
                            .font(.system(size: DS.IconSize.xs, weight: .semibold))
                        Text("Refresh")
                            .font(DS.Font.small)
                    }
                }
                .buttonStyle(.dsSecondary)
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

            if (catalog.packages.isEmpty && !catalog.isLoading && !isLiveSearch) {
                DSEmptyState(
                    icon: "puzzlepiece.extension",
                    title: "No Catalog Data",
                    subtitle: "Tap Refresh to fetch MCP servers from npm registry.",
                    action: { Task { await catalog.fetchCatalog() } },
                    actionTitle: "Fetch Catalog"
                )
            } else if isSearching && liveResults.isEmpty {
                VStack {
                    Spacer()
                    ProgressView("Searching...")
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Colors.textSecondary)
                    Spacer()
                }
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

                            if pkg.id != filteredPackages.last?.id || hasMore {
                                Divider()
                            }
                        }

                        if isLiveSearch && hasMore {
                            Button {
                                Task { await loadMore() }
                            } label: {
                                HStack(spacing: DS.Spacing.xs) {
                                    if isSearching { ProgressView().controlSize(.mini) }
                                    Text(isSearching ? "Loading..." : "Load More")
                                        .font(DS.Font.caption)
                                        .foregroundStyle(DS.Colors.textSecondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, DS.Spacing.md)
                            }
                            .buttonStyle(.plainPointer)
                            .disabled(isSearching)
                        }
                    }
                }
            }
        }
        .frame(width: 640, height: 560)
        .task(id: searchText) {
            guard !searchText.isEmpty else {
                liveResults = []
                hasMore = false
                liveFrom = 0
                return
            }
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            isSearching = true
            liveFrom = 0
            let results = await catalog.searchLive(query: searchText, from: 0)
            liveResults = results
            hasMore = results.count >= 20
            liveFrom = results.count
            isSearching = false
        }
        .onAppear {
            if catalog.needsRefresh {
                Task { await catalog.fetchCatalog() }
            }
        }
    }

    private func loadMore() async {
        guard !isSearching, hasMore else { return }
        isSearching = true
        let results = await catalog.searchLive(query: searchText, from: liveFrom)
        let existing = Set(liveResults.map(\.id))
        let fresh = results.filter { !existing.contains($0.id) }
        liveResults.append(contentsOf: fresh)
        hasMore = results.count >= 20
        liveFrom += results.count
        isSearching = false
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
                    .font(.system(size: DS.IconSize.sm, weight: .medium))
                    .foregroundStyle(DS.Colors.accent)
            }

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                HStack(spacing: DS.Spacing.sm) {
                    Text(package.displayName)
                        .font(DS.Font.body)
                        .fontWeight(.medium)

                    Text("v\(package.version)")
                        .font(DS.Font.small)
                        .foregroundStyle(DS.Colors.textTertiary)

                    DSPill(text: package.category, color: DS.Colors.info)
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
                    .buttonStyle(.dsSecondary)
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
