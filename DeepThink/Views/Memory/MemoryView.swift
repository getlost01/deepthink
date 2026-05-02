import SwiftUI

struct MemoryView: View {
    @State private var searchQuery = ""
    @State private var isSearching = false
    @State private var memoryEntries: [MemoryEntry] = []
    @State private var stats: MemoryStats?
    @State private var selectedLayer: MemoryLayer = .all
    @State private var newMemoryText = ""
    @State private var newMemoryTags = ""
    @State private var newMemoryLayer: String = "short"
    @State private var showAddSheet = false
    @State private var statusMessage: String?
    @FocusState private var searchFocused: Bool

    enum MemoryLayer: String, CaseIterable {
        case all = "All"
        case short = "Short-term"
        case long = "Long-term"
    }

    struct MemoryEntry: Identifiable {
        let id = UUID()
        let content: String
        let layer: String
        let tags: String
        let timestamp: String
    }

    struct MemoryStats {
        let shortTerm: Int
        let longTerm: Int
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: DS.Spacing.md) {
                HStack(spacing: DS.Spacing.md) {
                    Image(systemName: "brain")
                        .font(.system(size: DS.IconSize.md))
                        .foregroundStyle(DS.Colors.textTertiary)

                    TextField("Search memories...", text: $searchQuery)
                        .textFieldStyle(.plain)
                        .font(DS.Font.body)
                        .focused($searchFocused)
                        .onSubmit { searchMemories() }

                    if isSearching {
                        ProgressView().scaleEffect(0.7)
                    }

                    DSToolbarButton(icon: "magnifyingglass", color: DS.Colors.accent, size: DS.IconSize.md) {
                        searchMemories()
                    }
                    .disabled(searchQuery.isEmpty)
                }
                .dsInputField()

                HStack(spacing: DS.Spacing.md) {
                    Picker("Layer", selection: $selectedLayer) {
                        ForEach(MemoryLayer.allCases, id: \.self) { layer in
                            Text(layer.rawValue).tag(layer)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 280)

                    Spacer()

                    if let stats {
                        HStack(spacing: DS.Spacing.md) {
                            StatBadge(label: "Short", count: stats.shortTerm, color: DS.Colors.warning)
                            StatBadge(label: "Long", count: stats.longTerm, color: DS.Colors.info)
                        }
                    }

                    Button {
                        showAddSheet = true
                    } label: {
                        HStack(spacing: DS.Spacing.xs) {
                            Image(systemName: "plus")
                            Text("Remember")
                        }
                        .font(DS.Font.caption)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
            .padding(DS.Spacing.xl)
            .background(.bar)

            Divider()

            if memoryEntries.isEmpty {
                DSEmptyState(
                    icon: "brain",
                    title: "Memory Bank",
                    subtitle: "Search your memories or add new ones. DeepThink remembers context across sessions.",
                    action: { showAddSheet = true },
                    actionTitle: "Add Memory"
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: DS.Spacing.sm) {
                        ForEach(memoryEntries) { entry in
                            MemoryEntryRow(entry: entry)
                        }
                    }
                    .padding(DS.Spacing.xl)
                }
            }

            if let statusMessage {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "checkmark.circle")
                        .foregroundStyle(DS.Colors.success)
                    Text(statusMessage)
                        .font(DS.Font.caption)
                    Spacer()
                    Button("Dismiss") { self.statusMessage = nil }
                        .font(DS.Font.caption)
                        .buttonStyle(.plainPointer)
                }
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.vertical, DS.Spacing.sm)
                .background(.bar)
            }
        }
        .onAppear {
            searchFocused = true
            loadStats()
            loadRecent()
        }
        .sheet(isPresented: $showAddSheet) {
            AddMemorySheet(
                text: $newMemoryText,
                tags: $newMemoryTags,
                layer: $newMemoryLayer,
                onSave: saveMemory
            )
        }
    }

    private func searchMemories() {
        guard !searchQuery.isEmpty else { return }
        isSearching = true

        Task {
            let result = await DeepThinkCLIService.shared.recall(query: searchQuery, json: true)
            await MainActor.run {
                parseJSONMemories(result)
                isSearching = false
            }
        }
    }

    private func loadRecent() {
        Task {
            let result = await DeepThinkCLIService.shared.recall(query: "", json: true)
            await MainActor.run {
                parseJSONMemories(result)
            }
        }
    }

    private func loadStats() {
        Task {
            let result = await DeepThinkCLIService.shared.memoryStats(json: true)
            await MainActor.run {
                if let s = result.decoded(DeepThinkCLIService.CLIMemoryStats.self) {
                    stats = MemoryStats(shortTerm: s.shortTerm, longTerm: s.longTerm)
                }
            }
        }
    }

    private func parseJSONMemories(_ result: DeepThinkCLIService.CLIResult) {
        guard let recall = result.decoded(DeepThinkCLIService.CLIMemoryRecall.self) else {
            memoryEntries = []
            return
        }

        var entries = recall.entries.map { e in
            MemoryEntry(
                content: e.content,
                layer: e.layer,
                tags: e.tags.joined(separator: ", "),
                timestamp: String(e.timestamp.prefix(16))
            )
        }

        if selectedLayer != .all {
            let filterLayer = selectedLayer == .short ? "short" : "long"
            entries = entries.filter { $0.layer == filterLayer }
        }

        memoryEntries = entries
    }

    private func saveMemory() {
        guard !newMemoryText.isEmpty else { return }
        let tags = newMemoryTags.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }

        Task {
            let result = await DeepThinkCLIService.shared.remember(
                content: newMemoryText,
                tags: tags,
                layer: newMemoryLayer
            )
            await MainActor.run {
                if result.success {
                    statusMessage = "Memory saved"
                    newMemoryText = ""
                    newMemoryTags = ""
                    showAddSheet = false
                    loadStats()
                    loadRecent()
                } else {
                    statusMessage = "Error: \(result.error)"
                }
            }
        }
    }
}

private struct StatBadge: View {
    let label: String
    let count: Int
    let color: Color

    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            Text(label)
                .font(DS.Font.tiny)
                .foregroundStyle(DS.Colors.textSecondary)
            Text("\(count)")
                .font(DS.Font.caption)
                .fontWeight(.medium)
                .foregroundStyle(color)
        }
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.xs)
        .background(color.opacity(0.08), in: Capsule())
    }
}

private struct MemoryEntryRow: View {
    let entry: MemoryView.MemoryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: entry.layer == "long" ? "brain.fill" : "brain")
                    .font(.system(size: DS.IconSize.sm))
                    .foregroundStyle(entry.layer == "long" ? DS.Colors.info : DS.Colors.warning)

                Text(entry.timestamp)
                    .font(DS.Font.tiny)
                    .foregroundStyle(DS.Colors.textTertiary)

                DSPill(text: entry.layer, color: entry.layer == "long" ? DS.Colors.info : DS.Colors.warning)

                Spacer()

                DSToolbarButton(icon: "doc.on.doc", color: DS.Colors.textTertiary, size: DS.IconSize.xs + 1) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(entry.content, forType: .string)
                }
            }

            Text(entry.content)
                .font(DS.Font.body)
                .textSelection(.enabled)
                .lineLimit(4)

            if !entry.tags.isEmpty {
                HStack(spacing: DS.Spacing.xs) {
                    ForEach(entry.tags.components(separatedBy: ", "), id: \.self) { tag in
                        Text(tag)
                            .font(DS.Font.tiny)
                            .foregroundStyle(DS.Colors.textSecondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(DS.Colors.inputBg, in: Capsule())
                    }
                }
            }
        }
        .padding(DS.Spacing.md)
        .dsClickable()
    }
}

private struct AddMemorySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var text: String
    @Binding var tags: String
    @Binding var layer: String
    let onSave: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Add Memory")
                    .font(DS.Font.heading)
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plainPointer)
            }
            .padding(DS.Spacing.lg)

            Divider()

            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                Text("Content")
                    .font(DS.Font.sectionLabel)
                    .foregroundStyle(DS.Colors.textSecondary)
                TextEditor(text: $text)
                    .font(DS.Font.body)
                    .frame(minHeight: 100)
                    .padding(DS.Spacing.sm)
                    .background(DS.Colors.subtleBg, in: RoundedRectangle(cornerRadius: DS.Radius.sm))

                TextField("Tags (comma-separated)", text: $tags)
                    .textFieldStyle(.roundedBorder)

                Picker("Layer", selection: $layer) {
                    Text("Short-term").tag("short")
                    Text("Long-term").tag("long")
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }
            .padding(DS.Spacing.lg)

            Divider()

            HStack {
                Spacer()
                Button("Save") { onSave() }
                    .buttonStyle(.borderedProminent)
                    .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(DS.Spacing.lg)
        }
        .frame(width: 460, height: 340)
    }
}
