import Foundation
import SwiftData
import SwiftUI

@Observable
final class ClaudeService {
    static let shared = ClaudeService()

    var isProcessing = false
    var lastError: String?
    var lastErrorKind: ClaudeErrorKind?
    var maxTokens: Int = 16384

    /// Model selection — persisted across launches via UserDefaults
    var selectedModelFamily: ModelFamily = .sonnet {
        didSet {
            UserDefaults.standard.set(selectedModelFamily.rawValue, forKey: "selectedModelFamily")
        }
    }

    var selectedModelVersion: ModelVersion = .latestSonnet {
        didSet {
            UserDefaults.standard.set(selectedModelVersion.id, forKey: "selectedModelVersionID")
        }
    }

    // Usage tracking — all-time (loaded from DB + accumulated)
    var totalQueries: Int = 0
    var totalCostUSD: Double = 0
    var totalDurationMs: Double = 0
    var totalInputTokens: Int = 0
    var totalOutputTokens: Int = 0
    var totalCacheReadTokens: Int = 0
    // Usage tracking — current session only
    var lastQueryCostUSD: Double?
    var lastQueryDurationMs: Double?
    var sessionStartDate: Date = .init()
    var lastTokenUsage: TokenUsage?
    var sessionInputTokens: Int = 0
    var sessionOutputTokens: Int = 0
    var sessionCacheReadTokens: Int = 0
    var sessionCacheCreationTokens: Int = 0

    /// CLI info
    var cliVersion: String?

    private var container: ModelContainer?
    private var currentSession: UsageSession?

    func start(container: ModelContainer) {
        self.container = container
        let context = ModelContext(container)
        let session = UsageSession()
        context.insert(session)
        try? context.save()
        currentSession = session

        let descriptor = FetchDescriptor<UsageSession>()
        if let all = try? context.fetch(descriptor) {
            totalQueries = all.reduce(0) { $0 + $1.queries }
            totalCostUSD = all.reduce(0) { $0 + $1.costUSD }
            totalDurationMs = all.reduce(0) { $0 + $1.durationMs }
            totalInputTokens = all.reduce(0) { $0 + $1.inputTokens }
            totalOutputTokens = all.reduce(0) { $0 + $1.outputTokens }
            totalCacheReadTokens = all.reduce(0) { $0 + $1.cacheReadTokens }
            sessionStartDate = session.startDate
        }
    }

    func recordUsage(
        queries: Int = 0,
        cost: Double = 0,
        durationMs: Double = 0,
        inputTokens: Int = 0,
        outputTokens: Int = 0,
        cacheReadTokens: Int = 0,
        cacheCreationTokens: Int = 0
    ) {
        guard let container, let session = currentSession else { return }
        let context = ModelContext(container)
        session.queries += queries
        session.costUSD += cost
        session.durationMs += durationMs
        session.inputTokens += inputTokens
        session.outputTokens += outputTokens
        session.cacheReadTokens += cacheReadTokens
        context.insert(session)
        try? context.save()
        sessionCacheReadTokens += cacheReadTokens
        sessionCacheCreationTokens += cacheCreationTokens
        totalDurationMs += durationMs
        totalInputTokens += inputTokens
        totalOutputTokens += outputTokens
        totalCacheReadTokens += cacheReadTokens
    }

    struct ModelVersion: Identifiable, Hashable {
        let id: String
        let family: ModelFamily
        let version: String
        let suffix: String?
        let isLatest: Bool
        let contextWindow: String
        let maxOutput: String
        let inputCostPer1M: String
        let outputCostPer1M: String

        var displayName: String {
            "Claude \(family.rawValue.capitalized) \(version)\(suffix.map { " (\($0))" } ?? "")"
        }

        var modelID: String {
            id
        }

        static let opus47 = ModelVersion(
            id: "claude-opus-4-7",
            family: .opus,
            version: "4.7",
            suffix: "Latest",
            isLatest: true,
            contextWindow: "200K",
            maxOutput: "32K",
            inputCostPer1M: "$15",
            outputCostPer1M: "$75"
        )
        static let opus46 = ModelVersion(
            id: "claude-opus-4-6",
            family: .opus,
            version: "4.6",
            suffix: nil,
            isLatest: false,
            contextWindow: "200K",
            maxOutput: "32K",
            inputCostPer1M: "$15",
            outputCostPer1M: "$75"
        )
        static let opus45 = ModelVersion(
            id: "claude-opus-4-5-20250414",
            family: .opus,
            version: "4.5",
            suffix: nil,
            isLatest: false,
            contextWindow: "200K",
            maxOutput: "32K",
            inputCostPer1M: "$15",
            outputCostPer1M: "$75"
        )

        static let sonnet46 = ModelVersion(
            id: "claude-sonnet-4-6",
            family: .sonnet,
            version: "4.6",
            suffix: nil,
            isLatest: true,
            contextWindow: "200K",
            maxOutput: "16K",
            inputCostPer1M: "$3",
            outputCostPer1M: "$15"
        )
        static let sonnet45 = ModelVersion(
            id: "claude-sonnet-4-5-20241022",
            family: .sonnet,
            version: "4.5",
            suffix: nil,
            isLatest: false,
            contextWindow: "200K",
            maxOutput: "8K",
            inputCostPer1M: "$3",
            outputCostPer1M: "$15"
        )
        static let sonnet37 = ModelVersion(
            id: "claude-3-7-sonnet-20250219",
            family: .sonnet,
            version: "3.7",
            suffix: nil,
            isLatest: false,
            contextWindow: "200K",
            maxOutput: "8K",
            inputCostPer1M: "$3",
            outputCostPer1M: "$15"
        )

        static let haiku45 = ModelVersion(
            id: "claude-haiku-4-5-20251001",
            family: .haiku,
            version: "4.5",
            suffix: nil,
            isLatest: true,
            contextWindow: "200K",
            maxOutput: "8K",
            inputCostPer1M: "$0.80",
            outputCostPer1M: "$4"
        )
        static let haiku35 = ModelVersion(
            id: "claude-3-5-haiku-20241022",
            family: .haiku,
            version: "3.5",
            suffix: nil,
            isLatest: false,
            contextWindow: "200K",
            maxOutput: "8K",
            inputCostPer1M: "$0.80",
            outputCostPer1M: "$4"
        )

        // Legacy aliases
        static let latestOpus = opus47
        static let latestSonnet = sonnet46
        static let latestHaiku = haiku45
    }

    enum ModelFamily: String, CaseIterable, Identifiable {
        case haiku = "Haiku"
        case sonnet = "Sonnet"
        case opus = "Opus"

        var id: String {
            rawValue
        }

        var color: Color {
            switch self {
            case .haiku: .cyan
            case .sonnet: Color(hue: 0.08, saturation: 0.75, brightness: 0.95)
            case .opus: Color(hue: 0.75, saturation: 0.6, brightness: 0.85)
            }
        }

        var icon: String {
            switch self {
            case .haiku: "bolt.fill"
            case .sonnet: "sparkles"
            case .opus: "diamond.fill"
            }
        }

        var tagline: String {
            switch self {
            case .haiku: "Fast & affordable"
            case .sonnet: "Best balance of speed & intelligence"
            case .opus: "Most powerful & capable"
            }
        }

        var versions: [ModelVersion] {
            switch self {
            case .haiku: [.haiku45, .haiku35]
            case .sonnet: [.sonnet46, .sonnet45, .sonnet37]
            case .opus: [.opus47, .opus46, .opus45]
            }
        }

        var latestVersion: ModelVersion {
            switch self {
            case .haiku: .latestHaiku
            case .sonnet: .latestSonnet
            case .opus: .latestOpus
            }
        }
    }

    var modelDisplayName: String {
        selectedModelVersion.displayName
    }

    var fullModelID: String {
        selectedModelVersion.modelID
    }

    static let maxTokenOptions = [4096, 8192, 16384, 32768]

    var claudePath: String
    var customCLIPath: String? {
        didSet {
            if let path = customCLIPath, FileManager.default.isExecutableFile(atPath: path) {
                claudePath = path
                UserDefaults.standard.set(path, forKey: "claudeCLIPath")
                fetchCLIVersion()
            }
        }
    }

    private static let defaultCandidates = [
        "\(NSHomeDirectory())/.local/bin/claude",
        "/usr/local/bin/claude",
        "/opt/homebrew/bin/claude"
    ]

    private init() {
        if let saved = UserDefaults.standard.string(forKey: "claudeCLIPath"),
           FileManager.default.isExecutableFile(atPath: saved)
        {
            claudePath = saved
            customCLIPath = saved
        } else {
            claudePath = Self.defaultCandidates.first { FileManager.default.isExecutableFile(atPath: $0) } ?? ""
        }

        if let savedFamily = UserDefaults.standard.string(forKey: "selectedModelFamily"),
           let family = ModelFamily(rawValue: savedFamily)
        {
            selectedModelFamily = family
            if let savedVersionID = UserDefaults.standard.string(forKey: "selectedModelVersionID"),
               let version = family.versions.first(where: { $0.id == savedVersionID })
            {
                selectedModelVersion = version
            } else {
                selectedModelVersion = family.latestVersion
            }
        }

        fetchCLIVersion()
    }

    var isAvailable: Bool {
        !claudePath.isEmpty
    }

    /// Inspects raw CLI output/stderr text and returns a typed error if a known condition is detected.
    static func classifyOutput(_ text: String) -> ClaudeError? {
        let lower = text.lowercased()
        let isRateLimit = lower.contains("rate limit") || lower.contains("too many requests")
            || lower.contains("429") || lower.contains("overloaded") || lower.contains("rate_limit")
        let isCredits = lower.contains("credit balance") || lower.contains("insufficient_balance")
            || lower.contains("insufficient credits") || lower.contains("credit")
            && (lower.contains("low") || lower.contains("run out") || lower.contains("insufficient"))
            || lower.contains("402") || lower.contains("payment required")
            || lower.contains("billing") || lower.contains("usage limit")
        if isRateLimit { return .rateLimited }
        if isCredits { return .noCredits }
        return nil
    }

    func rescan() {
        if let saved = customCLIPath, FileManager.default.isExecutableFile(atPath: saved) {
            claudePath = saved
        } else {
            claudePath = Self.defaultCandidates.first { FileManager.default.isExecutableFile(atPath: $0) } ?? ""
        }
        fetchCLIVersion()
    }

    private func fetchCLIVersion() {
        guard isAvailable else { return }
        DispatchQueue.global(qos: .utility).async { [claudePath] in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: claudePath)
            process.arguments = ["--version"]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()
            try? process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let version = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            DispatchQueue.main.async {
                ClaudeService.shared.cliVersion = version
            }
        }
    }

    func refreshCLIVersion() {
        fetchCLIVersion()
    }

    struct CLIResponse: Codable {
        let type: String?
        let result: String?
        let is_error: Bool?
        let duration_ms: Double?
        let total_cost_usd: Double?
        let usage: CLIUsage?
    }

    struct CLIUsage: Codable {
        let input_tokens: Int?
        let output_tokens: Int?
        let cache_read_input_tokens: Int?
        let cache_creation_input_tokens: Int?
    }

    func query(_ prompt: String, systemPrompt: String? = nil, model: String? = nil) async throws -> String {
        guard isAvailable else {
            await MainActor.run { lastErrorKind = .notInstalled }
            throw ClaudeError.notInstalled
        }

        await MainActor.run { isProcessing = true; lastError = nil; lastErrorKind = nil }

        do {
            let result = try await runCLI(prompt: prompt, systemPrompt: systemPrompt, model: model)
            await MainActor.run { isProcessing = false }
            return result
        } catch {
            await MainActor.run {
                isProcessing = false
                lastError = error.localizedDescription
                lastErrorKind = (error as? ClaudeError)?.kind ?? .other
            }
            throw error
        }
    }

    private func runCLI(prompt: String, systemPrompt: String?, model: String? = nil, extraArgs: [String] = []) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [claudePath] in
                let storage = StorageService.shared
                let process = Process()
                process.executableURL = URL(fileURLWithPath: claudePath)
                process.currentDirectoryURL = storage.baseURL

                var args = [
                    "-p",
                    prompt,
                    "--output-format",
                    "json",
                    "--no-session-persistence",
                    "--model",
                    model ?? ClaudeService.shared.fullModelID
                ]
                if let systemPrompt {
                    args.append(contentsOf: ["--append-system-prompt", systemPrompt])
                }
                args.append(contentsOf: extraArgs)
                process.arguments = args

                var env = ProcessInfo.processInfo.environment
                env["HOME"] = NSHomeDirectory()
                env["PATH"] = "\(NSHomeDirectory())/.local/bin:/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:\(env["PATH"] ?? "")"
                env["DEEPTHINK_HOME"] = storage.baseURL.path
                process.environment = env

                storage.writeLog("Query: \(prompt.prefix(100))...", to: "claude")

                let outPipe = Pipe()
                let errPipe = Pipe()
                process.standardOutput = outPipe
                process.standardError = errPipe

                do {
                    try process.run()
                    process.waitUntilExit()

                    let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
                    let errData = errPipe.fileHandleForReading.readDataToEndOfFile()

                    if process.terminationStatus != 0 {
                        let stderr = String(data: errData, encoding: .utf8) ?? "Unknown error"
                        let combined = stderr + (String(data: outData, encoding: .utf8) ?? "")
                        if let typed = ClaudeService.classifyOutput(combined) {
                            continuation.resume(throwing: typed)
                        } else {
                            continuation.resume(throwing: ClaudeError.cliError("Exit \(process.terminationStatus): \(stderr)"))
                        }
                        return
                    }

                    let output = String(data: outData, encoding: .utf8) ?? ""

                    if let jsonData = output.data(using: .utf8),
                       let response = try? JSONDecoder().decode(CLIResponse.self, from: jsonData),
                       let result = response.result
                    {
                        let cost = response.total_cost_usd
                        let duration = response.duration_ms
                        let usage = response.usage
                        DispatchQueue.main.async {
                            ClaudeService.shared.totalQueries += 1
                            if let cost {
                                ClaudeService.shared.totalCostUSD += cost
                                ClaudeService.shared.lastQueryCostUSD = cost
                            }
                            ClaudeService.shared.lastQueryDurationMs = duration
                            var tu = TokenUsage()
                            tu.inputTokens = usage?.input_tokens ?? 0
                            tu.outputTokens = usage?.output_tokens ?? 0
                            tu.cacheReadTokens = usage?.cache_read_input_tokens ?? 0
                            tu.cacheCreationTokens = usage?.cache_creation_input_tokens ?? 0
                            tu.costUSD = cost ?? 0
                            tu.durationMs = duration ?? 0
                            ClaudeService.shared.lastTokenUsage = tu
                            ClaudeService.shared.sessionInputTokens += tu.inputTokens
                            ClaudeService.shared.sessionOutputTokens += tu.outputTokens
                            ClaudeService.shared.recordUsage(
                                queries: 1,
                                cost: cost ?? 0,
                                durationMs: tu.durationMs,
                                inputTokens: tu.inputTokens,
                                outputTokens: tu.outputTokens,
                                cacheReadTokens: tu.cacheReadTokens,
                                cacheCreationTokens: tu.cacheCreationTokens
                            )
                        }
                        continuation.resume(returning: result)
                    } else {
                        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
                        if trimmed.isEmpty {
                            continuation.resume(throwing: ClaudeError.cliError("Empty response from Claude"))
                        } else {
                            continuation.resume(returning: trimmed)
                        }
                    }
                } catch {
                    continuation.resume(throwing: ClaudeError.cliError("Failed to launch: \(error.localizedDescription)"))
                }
            }
        }
    }

    // MARK: - Streaming

    func streamQuery(_ prompt: String, systemPrompt: String? = nil, onToken: @escaping @Sendable (String) -> Void) async throws -> String {
        guard isAvailable else {
            await MainActor.run { lastErrorKind = .notInstalled }
            throw ClaudeError.notInstalled
        }

        await MainActor.run { isProcessing = true; lastError = nil; lastErrorKind = nil }

        do {
            let result = try await runCLIStreaming(prompt: prompt, systemPrompt: systemPrompt, onToken: onToken)
            await MainActor.run { isProcessing = false }
            return result
        } catch {
            await MainActor.run {
                isProcessing = false
                lastError = error.localizedDescription
                lastErrorKind = (error as? ClaudeError)?.kind ?? .other
            }
            throw error
        }
    }

    private func runCLIStreaming(prompt: String, systemPrompt: String?, onToken: @escaping @Sendable (String) -> Void) async throws -> String {
        let cliPath = claudePath
        let modelID = fullModelID
        let storage = StorageService.shared

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: cliPath)
                process.currentDirectoryURL = storage.baseURL

                var args = [
                    "-p",
                    prompt,
                    "--output-format",
                    "stream-json",
                    "--verbose",
                    "--no-session-persistence",
                    "--model",
                    modelID
                ]
                if let systemPrompt {
                    args.append(contentsOf: ["--append-system-prompt", systemPrompt])
                }
                process.arguments = args

                var env = ProcessInfo.processInfo.environment
                env["HOME"] = NSHomeDirectory()
                env["PATH"] = "\(NSHomeDirectory())/.local/bin:/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:\(env["PATH"] ?? "")"
                env["DEEPTHINK_HOME"] = storage.baseURL.path
                process.environment = env

                let outPipe = Pipe()
                let errPipe = Pipe()
                process.standardOutput = outPipe
                process.standardError = errPipe

                var fullText = ""

                do {
                    try process.run()

                    let handle = outPipe.fileHandleForReading
                    var buffer = Data()

                    while process.isRunning || !handle.availableData.isEmpty {
                        let chunk = handle.availableData
                        if chunk.isEmpty { break }
                        buffer.append(chunk)

                        while let newlineRange = buffer.range(of: Data("\n".utf8)) {
                            let lineData = buffer.subdata(in: buffer.startIndex..<newlineRange.lowerBound)
                            buffer.removeSubrange(buffer.startIndex...newlineRange.lowerBound)

                            guard let line = String(data: lineData, encoding: .utf8), !line.isEmpty else { continue }

                            if let jsonData = line.data(using: .utf8),
                               let obj = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
                            {
                                let type = obj["type"] as? String
                                if type == "assistant" || type == "content_block_delta" {
                                    if let text = obj["content"] as? String {
                                        fullText += text
                                        onToken(text)
                                    } else if let delta = obj["delta"] as? [String: Any],
                                              let text = delta["text"] as? String
                                    {
                                        fullText += text
                                        onToken(text)
                                    }
                                } else if type == "result" {
                                    if let result = obj["result"] as? String {
                                        fullText = result
                                    }
                                    let cost = obj["total_cost_usd"] as? Double
                                    let duration = obj["duration_ms"] as? Double
                                    let usageDict = obj["usage"] as? [String: Any]
                                    DispatchQueue.main.sync {
                                        ClaudeService.shared.totalQueries += 1
                                        if let cost {
                                            ClaudeService.shared.totalCostUSD += cost
                                            ClaudeService.shared.lastQueryCostUSD = cost
                                        }
                                        ClaudeService.shared.lastQueryDurationMs = duration
                                        var tu = TokenUsage()
                                        tu.inputTokens = usageDict?["input_tokens"] as? Int ?? 0
                                        tu.outputTokens = usageDict?["output_tokens"] as? Int ?? 0
                                        tu.cacheReadTokens = usageDict?["cache_read_input_tokens"] as? Int ?? 0
                                        tu.cacheCreationTokens = usageDict?["cache_creation_input_tokens"] as? Int ?? 0
                                        tu.costUSD = cost ?? 0
                                        tu.durationMs = duration ?? 0
                                        ClaudeService.shared.lastTokenUsage = tu
                                        ClaudeService.shared.sessionInputTokens += tu.inputTokens
                                        ClaudeService.shared.sessionOutputTokens += tu.outputTokens
                                        ClaudeService.shared.recordUsage(
                                            queries: 1,
                                            cost: cost ?? 0,
                                            durationMs: tu.durationMs,
                                            inputTokens: tu.inputTokens,
                                            outputTokens: tu.outputTokens,
                                            cacheReadTokens: tu.cacheReadTokens,
                                            cacheCreationTokens: tu.cacheCreationTokens
                                        )
                                    }
                                }
                            }
                        }
                    }

                    process.waitUntilExit()

                    if process.terminationStatus != 0, fullText.isEmpty {
                        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                        let stderr = String(data: errData, encoding: .utf8) ?? "Unknown error"
                        if let typed = ClaudeService.classifyOutput(stderr) {
                            continuation.resume(throwing: typed)
                        } else {
                            continuation.resume(throwing: ClaudeError.cliError("Exit \(process.terminationStatus): \(stderr)"))
                        }
                    } else {
                        continuation.resume(returning: fullText)
                    }
                } catch {
                    continuation.resume(throwing: ClaudeError.cliError("Failed to launch: \(error.localizedDescription)"))
                }
            }
        }
    }

    func summarize(_ text: String) async throws -> String {
        try await query(
            "Summarize the following concisely in 2-3 bullet points:\n\n\(text)",
            systemPrompt: "You are a concise summarizer. Output only bullet points, no preamble."
        )
    }

    func suggestTasks(from text: String) async throws -> [String] {
        let result = try await query(
            "Extract actionable tasks from this text. Return each task on its own line, prefixed with '- '. Only output tasks, nothing else:\n\n\(text)",
            systemPrompt: "You extract actionable tasks from text. Output only a markdown list of tasks."
        )
        return result
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.hasPrefix("- ") || $0.hasPrefix("* ") }
            .map { String($0.dropFirst(2)) }
    }

    func answer(_ question: String, context: String) async throws -> String {
        try await query(
            "Context:\n\(context)\n\nQuestion: \(question)",
            systemPrompt: "You are a helpful assistant answering questions based on the provided context. Be concise and accurate."
        )
    }

    func improveWriting(_ text: String) async throws -> String {
        try await query(
            "Improve the following text for clarity and conciseness. Return only the improved text:\n\n\(text)",
            systemPrompt: "You are an expert editor. Improve text for clarity while preserving meaning. Output only the improved text."
        )
    }

    func analyzeCLIOutput(_ output: String, question: String? = nil) async throws -> String {
        let prompt = if let question {
            "Analyze this command output and answer: \(question)\n\n```\n\(output.prefix(8000))\n```"
        } else {
            "Analyze this command output. Summarize key findings, highlight issues or anomalies, and suggest next steps if applicable:\n\n```\n\(output.prefix(8000))\n```"
        }
        return try await query(
            prompt,
            systemPrompt: "You are a CLI and devops expert. Analyze command output concisely. Use bullet points. Highlight errors, warnings, and anomalies."
        )
    }

    func explainError(_ command: String, stderr: String, exitCode: Int32) async throws -> String {
        let prompt = "Command: \(command)\nExit code: \(exitCode)\nError output:\n```\n\(stderr.prefix(4000))\n```\n\nExplain what went wrong and suggest a fix."
        return try await query(prompt, systemPrompt: "You are a CLI expert. Explain errors concisely and provide actionable fixes.")
    }

    func analyzeFile(at path: String, question: String? = nil) async throws -> String {
        let url = URL(fileURLWithPath: path)
        let content = try String(contentsOf: url, encoding: .utf8)
        let ext = url.pathExtension
        let prompt = if let question {
            "Analyze this \(ext) file and answer: \(question)\n\n```\(ext)\n\(content.prefix(10000))\n```"
        } else {
            "Analyze this \(ext) file. Describe its purpose, highlight key patterns, potential issues, and suggest improvements:\n\n```\(ext)\n\(content.prefix(10000))\n```"
        }
        return try await query(prompt, systemPrompt: "You are a code and data analysis expert. Be concise and actionable.")
    }
}

enum ClaudeError: LocalizedError {
    case cliError(String)
    case notInstalled
    case rateLimited
    case noCredits

    var errorDescription: String? {
        switch self {
        case let .cliError(msg): msg
        case .notInstalled: "Claude CLI not found at ~/.local/bin/claude. Install from https://claude.ai/code"
        case .rateLimited: "Rate limit reached — Claude is temporarily unavailable. Please wait a moment and try again, or check your plan limits at console.anthropic.com."
        case .noCredits: "Your Claude API account has run out of credits. Add credits at console.anthropic.com to continue using AI features."
        }
    }

    var kind: ClaudeErrorKind {
        switch self {
        case .rateLimited: .rateLimited
        case .noCredits: .noCredits
        case .notInstalled: .notInstalled
        case .cliError: .other
        }
    }
}

enum ClaudeErrorKind: Equatable {
    case rateLimited
    case noCredits
    case notInstalled
    case other
}
