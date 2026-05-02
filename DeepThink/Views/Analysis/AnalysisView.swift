import SwiftUI

struct AnalysisView: View {
    @State private var inputMode: InputMode = .command
    @State private var commandText = ""
    @State private var questionText = ""
    @State private var isRunning = false
    @State private var results: [AnalysisResultItem] = []
    @State private var selectedResultID: UUID?
    @State private var droppedFilePath: String?
    @FocusState private var commandFocused: Bool

    enum InputMode: String, CaseIterable {
        case command = "Command"
        case file = "File"
        case url = "URL"
        case data = "Data Analysis"
    }

    struct AnalysisResultItem: Identifiable {
        let id = UUID()
        let source: String
        let rawOutput: String
        let analysis: String
        let timestamp: Date
        let isError: Bool
        var parsedData: ParsedDataFile?
    }

    enum ParsedDataFile {
        case csv(CSVData)
        case json(JSONData)
    }

    struct CSVData {
        let headers: [String]
        let rows: [[String]]
        let columnStats: [ColumnStat]
    }

    struct ColumnStat: Identifiable {
        let id = UUID()
        let name: String
        let isNumeric: Bool
        let min: Double?
        let max: Double?
        let mean: Double?
        let uniqueCount: Int
    }

    struct JSONData {
        let prettyPrinted: String
        let structureInfo: String
        let tabularHeaders: [String]?
        let tabularRows: [[String]]?
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: DS.Spacing.md) {
                Picker("Mode", selection: $inputMode) {
                    ForEach(InputMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 240)

                HStack(spacing: DS.Spacing.md) {
                    Image(systemName: inputIcon)
                        .font(.system(size: DS.IconSize.md))
                        .foregroundStyle(DS.Colors.textTertiary)

                    TextField(inputPlaceholder, text: $commandText)
                        .textFieldStyle(.plain)
                        .font(inputMode == .command ? DS.Font.mono : DS.Font.body)
                        .focused($commandFocused)
                        .onSubmit { runAnalysis() }

                    if isRunning {
                        ProgressView().scaleEffect(0.7)
                    }

                    Button(action: runAnalysis) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: DS.IconSize.xl - 2))
                            .foregroundStyle(commandText.isEmpty ? DS.Colors.textTertiary : DS.Colors.accent)
                    }
                    .buttonStyle(.plainPointer)
                    .disabled(commandText.isEmpty || isRunning)
                }
                .dsInputField()

                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: DS.IconSize.sm))
                        .foregroundStyle(DS.Colors.textTertiary)
                    TextField("Ask a specific question about the output (optional)", text: $questionText)
                        .textFieldStyle(.plain)
                        .font(DS.Font.caption)
                }
                .padding(.horizontal, DS.Spacing.md)
            }
            .padding(DS.Spacing.xl)
            .background(.bar)

            Divider()

            if results.isEmpty {
                ScrollView {
                    VStack(spacing: DS.Spacing.xl) {
                        DSEmptyState(
                            icon: "wand.and.rays",
                            title: "Analyze Anything",
                            subtitle: "Run a shell command, open a file, or fetch a URL — AI will explain what it finds"
                        )
                        .frame(height: 180)

                        VStack(alignment: .leading, spacing: DS.Spacing.md) {
                            Text("Quick Analysis")
                                .font(DS.Font.heading)
                                .padding(.horizontal, DS.Spacing.xl)

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DS.Spacing.sm) {
                                ForEach(presetCommands, id: \.name) { preset in
                                    Button {
                                        commandText = preset.command
                                        inputMode = .command
                                        runAnalysis()
                                    } label: {
                                        HStack(spacing: DS.Spacing.sm) {
                                            Image(systemName: preset.icon)
                                                .font(.system(size: DS.IconSize.sm))
                                                .foregroundStyle(DS.Colors.accent)
                                                .frame(width: 24, height: 24)
                                                .background(DS.Colors.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(preset.name)
                                                    .font(DS.Font.caption)
                                                    .fontWeight(.medium)
                                                Text(preset.description)
                                                    .font(DS.Font.tiny)
                                                    .foregroundStyle(DS.Colors.textTertiary)
                                                    .lineLimit(1)
                                            }
                                            Spacer()
                                        }
                                        .padding(DS.Spacing.md)
                                        .dsClickable()
                                    }
                                    .buttonStyle(.plainPointer)
                                }
                            }
                            .padding(.horizontal, DS.Spacing.xl)
                        }
                    }
                    .padding(.top, DS.Spacing.xl)
                }
            } else {
                HSplitView {
                    List(selection: $selectedResultID) {
                        ForEach(results) { result in
                            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                                Text(result.source)
                                    .font(DS.Font.caption)
                                    .fontWeight(.medium)
                                    .lineLimit(1)
                                Text(result.timestamp, style: .time)
                                    .font(DS.Font.tiny)
                                    .foregroundStyle(DS.Colors.textTertiary)
                            }
                            .tag(result.id)
                            .padding(.vertical, DS.Spacing.xs)
                        }
                    }
                    .listStyle(.inset)
                    .frame(minWidth: 180, idealWidth: 220, maxWidth: 260)

                    if let result = results.first(where: { $0.id == selectedResultID }) {
                        AnalysisDetailView(result: result)
                    } else if let first = results.first {
                        AnalysisDetailView(result: first)
                    }
                }
            }
        }
        .onAppear { commandFocused = true }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleFileDrop(providers)
            return true
        }
    }

    private var inputIcon: String {
        switch inputMode {
        case .command: "terminal"
        case .file: "doc"
        case .url: "globe"
        case .data: "chart.bar"
        }
    }

    private var inputPlaceholder: String {
        switch inputMode {
        case .command: "Enter command to run and analyze..."
        case .file: "Enter file path to analyze..."
        case .url: "Enter URL to fetch and analyze..."
        case .data: "Enter CSV/JSON file path for data analysis..."
        }
    }

    private let presetCommands: [(name: String, command: String, icon: String, description: String)] = [
        ("Git Status", "git status && git log --oneline -10", "arrow.triangle.branch", "Repository status and recent commits"),
        ("Disk Usage", "df -h && du -sh * 2>/dev/null | sort -rh | head -20", "internaldrive", "Disk space overview"),
        ("Top Processes", "ps aux --sort=-%mem | head -20", "cpu", "Processes by memory usage"),
        ("Network", "lsof -i -P -n 2>/dev/null | head -30", "network", "Active network connections"),
        ("Docker", "docker ps -a 2>/dev/null && docker images 2>/dev/null | head -20", "shippingbox", "Docker containers and images"),
        ("System Info", "sw_vers && sysctl -n machdep.cpu.brand_string", "desktopcomputer", "macOS version and hardware"),
        ("Brew Health", "brew outdated 2>/dev/null && brew doctor 2>/dev/null | head -20", "mug", "Homebrew package status"),
        ("npm Audit", "npm audit 2>/dev/null || echo 'No package.json'", "shield", "Dependency vulnerabilities"),
        ("DeepThink Status", "deepthink status 2>/dev/null || echo 'CLI not set up'", "brain", "DeepThink CLI system status"),
        ("Memory Stats", "deepthink memory 2>/dev/null || echo 'CLI not set up'", "brain.head.profile", "Memory bank statistics"),
    ]

    private func runAnalysis() {
        guard !commandText.isEmpty else { return }
        isRunning = true
        let cmd = commandText
        let question = questionText.isEmpty ? nil : questionText
        let mode = inputMode

        Task {
            do {
                let rawOutput: String
                let source: String

                switch mode {
                case .command:
                    rawOutput = try await shellRun(cmd)
                    source = cmd
                case .file:
                    let url = URL(fileURLWithPath: cmd)
                    rawOutput = try String(contentsOf: url, encoding: .utf8)
                    source = "File: \(url.lastPathComponent)"
                case .url:
                    rawOutput = try await shellRun("curl -sL '\(cmd)' | head -500")
                    source = "URL: \(cmd)"
                case .data:
                    let fileURL = URL(fileURLWithPath: cmd)
                    let fileContent = try String(contentsOf: fileURL, encoding: .utf8)
                    rawOutput = fileContent
                    source = "Data: \(fileURL.lastPathComponent)"
                }

                var parsedData: ParsedDataFile?
                var dataSummary: String?

                if mode == .data {
                    let ext = (cmd as NSString).pathExtension.lowercased()
                    if ext == "csv" {
                        let csv = Self.parseCSV(rawOutput)
                        parsedData = .csv(csv)
                        dataSummary = Self.csvSummary(csv)
                    } else if ext == "json" || ext == "jsonl" {
                        let json = Self.parseJSON(rawOutput)
                        parsedData = .json(json)
                        dataSummary = json.structureInfo
                    }
                }

                let analysisPrompt: String
                if let summary = dataSummary {
                    let truncatedRaw = String(rawOutput.prefix(3000))
                    analysisPrompt = "Data structure summary:\n\(summary)\n\nRaw data (truncated):\n\(truncatedRaw)"
                } else {
                    analysisPrompt = rawOutput
                }

                let analysis = try await ClaudeService.shared.analyzeCLIOutput(
                    analysisPrompt,
                    question: question
                )

                var item = AnalysisResultItem(
                    source: source,
                    rawOutput: String(rawOutput.prefix(5000)),
                    analysis: analysis,
                    timestamp: Date(),
                    isError: false
                )
                item.parsedData = parsedData

                await MainActor.run {
                    results.insert(item, at: 0)
                    selectedResultID = item.id
                    isRunning = false
                    commandText = ""
                    questionText = ""
                }
            } catch {
                let item = AnalysisResultItem(
                    source: cmd,
                    rawOutput: "",
                    analysis: "Error: \(error.localizedDescription)",
                    timestamp: Date(),
                    isError: true
                )
                await MainActor.run {
                    results.insert(item, at: 0)
                    selectedResultID = item.id
                    isRunning = false
                }
            }
        }
    }

    private func shellRun(_ command: String) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/zsh")
                process.arguments = ["-l", "-c", command]

                var env = ProcessInfo.processInfo.environment
                env["TERM"] = "xterm-256color"
                process.environment = env

                let outPipe = Pipe()
                let errPipe = Pipe()
                process.standardOutput = outPipe
                process.standardError = errPipe

                do {
                    try process.run()
                    process.waitUntilExit()
                    let out = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                    let err = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                    continuation.resume(returning: out + (err.isEmpty ? "" : "\nSTDERR:\n\(err)"))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func handleFileDrop(_ providers: [NSItemProvider]) {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                let ext = url.pathExtension.lowercased()
                DispatchQueue.main.async {
                    commandText = url.path
                    if ext == "csv" || ext == "json" || ext == "jsonl" {
                        inputMode = .data
                    } else {
                        inputMode = .file
                    }
                }
            }
        }
    }

    // MARK: - CSV Parsing

    static func parseCSV(_ content: String) -> CSVData {
        let lines = content.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard let headerLine = lines.first else {
            return CSVData(headers: [], rows: [], columnStats: [])
        }

        let headers = parseCSVLine(headerLine)
        let dataRows = lines.dropFirst().map { parseCSVLine($0) }

        // Normalize row lengths to header count
        let colCount = headers.count
        let normalizedRows = dataRows.map { row -> [String] in
            if row.count >= colCount {
                return Array(row.prefix(colCount))
            } else {
                return row + Array(repeating: "", count: colCount - row.count)
            }
        }

        // Compute column stats
        var stats: [ColumnStat] = []
        for (i, header) in headers.enumerated() where i < 20 {
            let values = normalizedRows.map { i < $0.count ? $0[i] : "" }
            let numericValues = values.compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
            let isNumeric = numericValues.count > values.count / 2 && !numericValues.isEmpty

            if isNumeric {
                stats.append(ColumnStat(
                    name: header,
                    isNumeric: true,
                    min: numericValues.min(),
                    max: numericValues.max(),
                    mean: numericValues.reduce(0, +) / Double(numericValues.count),
                    uniqueCount: Set(values).count
                ))
            } else {
                stats.append(ColumnStat(
                    name: header,
                    isNumeric: false,
                    min: nil,
                    max: nil,
                    mean: nil,
                    uniqueCount: Set(values).count
                ))
            }
        }

        return CSVData(
            headers: Array(headers.prefix(20)),
            rows: normalizedRows,
            columnStats: stats
        )
    }

    private static func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false

        for ch in line {
            if ch == "\"" {
                inQuotes.toggle()
            } else if ch == "," && !inQuotes {
                fields.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            } else {
                current.append(ch)
            }
        }
        fields.append(current.trimmingCharacters(in: .whitespaces))
        return fields
    }

    static func csvSummary(_ csv: CSVData) -> String {
        var lines: [String] = []
        lines.append("CSV File: \(csv.rows.count) rows, \(csv.headers.count) columns")
        lines.append("Columns: \(csv.headers.joined(separator: ", "))")
        for stat in csv.columnStats {
            if stat.isNumeric {
                let minStr = stat.min.map { String(format: "%.2f", $0) } ?? "N/A"
                let maxStr = stat.max.map { String(format: "%.2f", $0) } ?? "N/A"
                let meanStr = stat.mean.map { String(format: "%.2f", $0) } ?? "N/A"
                lines.append("  \(stat.name): numeric, min=\(minStr), max=\(maxStr), mean=\(meanStr), \(stat.uniqueCount) unique")
            } else {
                lines.append("  \(stat.name): string, \(stat.uniqueCount) unique values")
            }
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - JSON Parsing

    static func parseJSON(_ content: String) -> JSONData {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8) else {
            return JSONData(prettyPrinted: content, structureInfo: "Invalid UTF-8", tabularHeaders: nil, tabularRows: nil)
        }

        let jsonObject: Any
        do {
            jsonObject = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        } catch {
            return JSONData(prettyPrinted: content, structureInfo: "Parse error: \(error.localizedDescription)", tabularHeaders: nil, tabularRows: nil)
        }

        // Pretty print
        let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted, .sortedKeys])
        let pretty = prettyData.flatMap { String(data: $0, encoding: .utf8) } ?? content

        // Structure info
        var info: [String] = []
        var tabHeaders: [String]?
        var tabRows: [[String]]?

        if let array = jsonObject as? [[String: Any]] {
            info.append("Array of \(array.count) objects")
            if let first = array.first {
                let keys = first.keys.sorted()
                info.append("Keys: \(keys.joined(separator: ", "))")
                for key in keys {
                    let typeName = Self.jsonTypeName(first[key])
                    info.append("  \(key): \(typeName)")
                }

                // Build tabular view
                let allKeys = Array(keys.prefix(20))
                tabHeaders = allKeys
                tabRows = array.map { obj in
                    allKeys.map { key in
                        Self.jsonValueString(obj[key])
                    }
                }
            }
        } else if let dict = jsonObject as? [String: Any] {
            info.append("Object with \(dict.count) keys")
            for key in dict.keys.sorted() {
                let val = dict[key]
                if let arr = val as? [Any] {
                    info.append("  \(key): array[\(arr.count)]")
                } else {
                    info.append("  \(key): \(Self.jsonTypeName(val))")
                }
            }
        } else if let array = jsonObject as? [Any] {
            info.append("Array of \(array.count) elements")
            if let first = array.first {
                info.append("Element type: \(Self.jsonTypeName(first))")
            }
        } else {
            info.append("Scalar value: \(Self.jsonTypeName(jsonObject))")
        }

        return JSONData(
            prettyPrinted: pretty,
            structureInfo: info.joined(separator: "\n"),
            tabularHeaders: tabHeaders,
            tabularRows: tabRows
        )
    }

    private static func jsonTypeName(_ value: Any?) -> String {
        switch value {
        case is String: return "string"
        case is Int, is Double, is Float: return "number"
        case is Bool: return "boolean"
        case is [Any]: return "array"
        case is [String: Any]: return "object"
        case is NSNull: return "null"
        case nil: return "null"
        default: return "unknown"
        }
    }

    private static func jsonValueString(_ value: Any?) -> String {
        switch value {
        case let s as String: return s
        case let n as NSNumber: return n.stringValue
        case is NSNull: return "null"
        case nil: return ""
        case let a as [Any]: return "[\(a.count) items]"
        case let d as [String: Any]: return "{\(d.count) keys}"
        default: return String(describing: value!)
        }
    }
}

private struct AnalysisDetailView: View {
    let result: AnalysisView.AnalysisResultItem

    enum DetailTab: String, CaseIterable {
        case analysis = "Analysis"
        case data = "Data"
        case raw = "Raw Output"
    }

    @State private var selectedTab: DetailTab = .analysis

    private var hasData: Bool { result.parsedData != nil }

    private var availableTabs: [DetailTab] {
        hasData ? DetailTab.allCases : [.analysis, .raw]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: DS.Spacing.sm) {
                Text(result.source)
                    .font(DS.Font.body)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Spacer()

                Picker("", selection: $selectedTab) {
                    ForEach(availableTabs, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: hasData ? 270 : 180)

                DSToolbarButton(icon: "doc.on.doc", color: DS.Colors.textTertiary, size: DS.IconSize.sm) {
                    let text: String
                    switch selectedTab {
                    case .analysis: text = result.analysis
                    case .data: text = result.rawOutput
                    case .raw: text = result.rawOutput
                    }
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                }
                .help("Copy to clipboard")
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.vertical, DS.Spacing.md)
            .background(.bar)

            Divider()

            switch selectedTab {
            case .analysis:
                ScrollView {
                    if let attributed = try? AttributedString(markdown: result.analysis, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
                        Text(attributed)
                            .font(DS.Font.body)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(DS.Spacing.lg)
                    } else {
                        Text(result.analysis)
                            .font(DS.Font.body)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(DS.Spacing.lg)
                    }
                }
            case .data:
                if let parsedData = result.parsedData {
                    DataPreviewView(data: parsedData)
                } else {
                    DSEmptyState(
                        icon: "tablecells",
                        title: "No Structured Data",
                        subtitle: "This result does not contain parseable CSV or JSON data"
                    )
                }
            case .raw:
                ScrollView {
                    Text(result.rawOutput)
                        .font(DS.Font.mono)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(DS.Spacing.lg)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Data Preview View

private struct DataPreviewView: View {
    let data: AnalysisView.ParsedDataFile

    @State private var sortColumn: String?
    @State private var sortAscending = true
    @State private var jsonShowTable = true

    var body: some View {
        switch data {
        case .csv(let csv):
            csvView(csv)
        case .json(let json):
            jsonView(json)
        }
    }

    // MARK: - CSV View

    @ViewBuilder
    private func csvView(_ csv: AnalysisView.CSVData) -> some View {
        VStack(spacing: 0) {
            // Stats bar
            HStack(spacing: DS.Spacing.lg) {
                statBadge(icon: "tablecells", label: "\(csv.rows.count) rows")
                statBadge(icon: "tablecells.badge.ellipsis", label: "\(csv.headers.count) columns")
                Spacer()
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.vertical, DS.Spacing.sm)
            .background(.bar)

            Divider()

            // Column stats
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Spacing.sm) {
                    ForEach(csv.columnStats) { stat in
                        columnStatCard(stat)
                    }
                }
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.vertical, DS.Spacing.sm)
            }

            Divider()

            // Data table
            ScrollView([.horizontal, .vertical]) {
                let sortedRows = sortRows(csv.rows, headers: csv.headers)
                LazyVStack(alignment: .leading, spacing: 0) {
                    // Header row
                    HStack(spacing: 0) {
                        ForEach(Array(csv.headers.enumerated()), id: \.offset) { idx, header in
                            Button {
                                if sortColumn == header {
                                    sortAscending.toggle()
                                } else {
                                    sortColumn = header
                                    sortAscending = true
                                }
                            } label: {
                                HStack(spacing: DS.Spacing.xs) {
                                    Text(header)
                                        .font(DS.Font.caption)
                                        .fontWeight(.semibold)
                                    if sortColumn == header {
                                        Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                                            .font(.system(size: 8))
                                    }
                                }
                                .frame(minWidth: 100, alignment: .leading)
                                .padding(.horizontal, DS.Spacing.sm)
                                .padding(.vertical, DS.Spacing.xs)
                            }
                            .buttonStyle(.plainPointer)

                            if idx < csv.headers.count - 1 {
                                Divider().frame(height: 20)
                            }
                        }
                    }
                    .background(DS.Colors.accent.opacity(0.06))

                    Divider()

                    // Data rows
                    ForEach(Array(sortedRows.enumerated()), id: \.offset) { rowIdx, row in
                        HStack(spacing: 0) {
                            ForEach(Array(row.enumerated()), id: \.offset) { colIdx, value in
                                Text(value)
                                    .font(DS.Font.mono)
                                    .lineLimit(1)
                                    .frame(minWidth: 100, alignment: .leading)
                                    .padding(.horizontal, DS.Spacing.sm)
                                    .padding(.vertical, DS.Spacing.xs)

                                if colIdx < row.count - 1 {
                                    Divider().frame(height: 18)
                                }
                            }
                        }
                        .background(rowIdx % 2 == 0 ? Color.clear : DS.Colors.textTertiary.opacity(0.04))
                    }
                }
            }
        }
    }

    // MARK: - JSON View

    @ViewBuilder
    private func jsonView(_ json: AnalysisView.JSONData) -> some View {
        VStack(spacing: 0) {
            // Structure info bar
            HStack(spacing: DS.Spacing.lg) {
                Image(systemName: "curlybraces")
                    .font(.system(size: DS.IconSize.sm))
                    .foregroundStyle(DS.Colors.accent)
                Text(json.structureInfo.components(separatedBy: "\n").first ?? "JSON")
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Colors.textSecondary)

                Spacer()

                if json.tabularHeaders != nil {
                    Picker("", selection: $jsonShowTable) {
                        Text("Table").tag(true)
                        Text("JSON").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 140)
                }
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.vertical, DS.Spacing.sm)
            .background(.bar)

            Divider()

            // Structure details
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                ForEach(json.structureInfo.components(separatedBy: "\n").dropFirst(), id: \.self) { line in
                    Text(line)
                        .font(DS.Font.mono)
                        .foregroundStyle(DS.Colors.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.vertical, DS.Spacing.sm)

            Divider()

            if jsonShowTable, let headers = json.tabularHeaders, let rows = json.tabularRows {
                // Table view for array-of-objects
                ScrollView([.horizontal, .vertical]) {
                    let sortedRows = sortRows(rows, headers: headers)
                    LazyVStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 0) {
                            ForEach(Array(headers.enumerated()), id: \.offset) { idx, header in
                                Button {
                                    if sortColumn == header {
                                        sortAscending.toggle()
                                    } else {
                                        sortColumn = header
                                        sortAscending = true
                                    }
                                } label: {
                                    HStack(spacing: DS.Spacing.xs) {
                                        Text(header)
                                            .font(DS.Font.caption)
                                            .fontWeight(.semibold)
                                        if sortColumn == header {
                                            Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                                                .font(.system(size: 8))
                                        }
                                    }
                                    .frame(minWidth: 120, alignment: .leading)
                                    .padding(.horizontal, DS.Spacing.sm)
                                    .padding(.vertical, DS.Spacing.xs)
                                }
                                .buttonStyle(.plainPointer)

                                if idx < headers.count - 1 {
                                    Divider().frame(height: 20)
                                }
                            }
                        }
                        .background(DS.Colors.accent.opacity(0.06))

                        Divider()

                        ForEach(Array(sortedRows.enumerated()), id: \.offset) { rowIdx, row in
                            HStack(spacing: 0) {
                                ForEach(Array(row.enumerated()), id: \.offset) { colIdx, value in
                                    Text(value)
                                        .font(DS.Font.mono)
                                        .lineLimit(2)
                                        .frame(minWidth: 120, alignment: .leading)
                                        .padding(.horizontal, DS.Spacing.sm)
                                        .padding(.vertical, DS.Spacing.xs)

                                    if colIdx < row.count - 1 {
                                        Divider().frame(height: 22)
                                    }
                                }
                            }
                            .background(rowIdx % 2 == 0 ? Color.clear : DS.Colors.textTertiary.opacity(0.04))
                        }
                    }
                }
            } else {
                // Pretty-printed JSON with syntax highlighting
                ScrollView {
                    Text(syntaxHighlightedJSON(json.prettyPrinted))
                        .font(DS.Font.mono)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(DS.Spacing.lg)
                }
            }
        }
    }

    // MARK: - Helpers

    private func statBadge(icon: String, label: String) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: DS.IconSize.sm))
                .foregroundStyle(DS.Colors.accent)
            Text(label)
                .font(DS.Font.caption)
                .foregroundStyle(DS.Colors.textSecondary)
        }
    }

    private func columnStatCard(_ stat: AnalysisView.ColumnStat) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(stat.name)
                .font(DS.Font.caption)
                .fontWeight(.medium)
                .lineLimit(1)

            if stat.isNumeric {
                HStack(spacing: DS.Spacing.sm) {
                    miniStat("Min", stat.min.map { formatNumber($0) } ?? "-")
                    miniStat("Max", stat.max.map { formatNumber($0) } ?? "-")
                    miniStat("Mean", stat.mean.map { formatNumber($0) } ?? "-")
                }
            } else {
                miniStat("Unique", "\(stat.uniqueCount)")
            }
        }
        .padding(DS.Spacing.sm)
        .background(DS.Colors.textTertiary.opacity(0.06), in: RoundedRectangle(cornerRadius: DS.Radius.sm))
    }

    private func miniStat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(DS.Font.tiny)
                .foregroundStyle(DS.Colors.textTertiary)
            Text(value)
                .font(DS.Font.mono)
                .lineLimit(1)
        }
    }

    private func formatNumber(_ n: Double) -> String {
        if n == n.rounded() && abs(n) < 1e9 {
            return String(format: "%.0f", n)
        }
        return String(format: "%.2f", n)
    }

    private func sortRows(_ rows: [[String]], headers: [String]) -> [[String]] {
        guard let col = sortColumn, let idx = headers.firstIndex(of: col) else { return rows }
        return rows.sorted { a, b in
            let va = idx < a.count ? a[idx] : ""
            let vb = idx < b.count ? b[idx] : ""
            // Try numeric comparison first
            if let na = Double(va), let nb = Double(vb) {
                return sortAscending ? na < nb : na > nb
            }
            return sortAscending ? va.localizedCompare(vb) == .orderedAscending : va.localizedCompare(vb) == .orderedDescending
        }
    }

    private func syntaxHighlightedJSON(_ json: String) -> AttributedString {
        var result = AttributedString(json)

        // Color strings (values between quotes)
        let nsJson = json as NSString
        let stringPattern = try? NSRegularExpression(pattern: "\"[^\"\\\\]*(?:\\\\.[^\"\\\\]*)*\"", options: [])
        let matches = stringPattern?.matches(in: json, options: [], range: NSRange(location: 0, length: nsJson.length)) ?? []

        for match in matches {
            guard let swiftRange = Range(match.range, in: json) else { continue }
            let attrRange = result.range(of: String(json[swiftRange]))
            if let attrRange {
                let matchedStr = String(json[swiftRange])
                // Check if followed by colon (it's a key)
                let afterEnd = match.range.location + match.range.length
                let isKey = afterEnd < nsJson.length && {
                    let remaining = nsJson.substring(from: afterEnd).trimmingCharacters(in: .whitespaces)
                    return remaining.hasPrefix(":")
                }()

                if isKey {
                    result[attrRange].foregroundColor = NSColor(DS.Colors.accent)
                } else {
                    result[attrRange].foregroundColor = .systemGreen
                }
            }
        }

        // Color numbers, booleans, null
        let tokenPattern = try? NSRegularExpression(pattern: "(?<=[:,\\[\\s])\\s*(true|false|null|-?\\d+\\.?\\d*(?:[eE][+-]?\\d+)?)(?=[,\\]\\}\\s])", options: [])
        let tokenMatches = tokenPattern?.matches(in: json, options: [], range: NSRange(location: 0, length: nsJson.length)) ?? []

        for match in tokenMatches {
            let captureRange = match.range(at: 1)
            guard let swiftRange = Range(captureRange, in: json) else { continue }
            let token = String(json[swiftRange])
            if let attrRange = result.range(of: token) {
                if token == "true" || token == "false" {
                    result[attrRange].foregroundColor = .systemOrange
                } else if token == "null" {
                    result[attrRange].foregroundColor = .systemRed
                } else {
                    result[attrRange].foregroundColor = .systemCyan
                }
            }
        }

        return result
    }
}
