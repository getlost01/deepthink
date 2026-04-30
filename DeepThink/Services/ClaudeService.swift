import Foundation

@Observable
final class ClaudeService {
    static let shared = ClaudeService()

    var isProcessing = false
    var lastError: String?
    var selectedModel: String = "sonnet"
    var maxTokens: Int = 4096

    private let claudePath: String

    private init() {
        let candidates = [
            "\(NSHomeDirectory())/.local/bin/claude",
            "/usr/local/bin/claude",
            "/opt/homebrew/bin/claude"
        ]
        self.claudePath = candidates.first { FileManager.default.isExecutableFile(atPath: $0) } ?? ""
    }

    var isAvailable: Bool { !claudePath.isEmpty }

    struct CLIResponse: Codable {
        let type: String?
        let result: String?
        let is_error: Bool?
        let duration_ms: Double?
        let total_cost_usd: Double?
    }

    func query(_ prompt: String, systemPrompt: String? = nil) async throws -> String {
        guard isAvailable else { throw ClaudeError.notInstalled }

        await MainActor.run { isProcessing = true; lastError = nil }

        do {
            let result = try await runCLI(prompt: prompt, systemPrompt: systemPrompt)
            await MainActor.run { isProcessing = false }
            return result
        } catch {
            await MainActor.run { isProcessing = false; lastError = error.localizedDescription }
            throw error
        }
    }

    private func runCLI(prompt: String, systemPrompt: String?, extraArgs: [String] = []) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [claudePath] in
                let storage = StorageService.shared
                let process = Process()
                process.executableURL = URL(fileURLWithPath: claudePath)
                process.currentDirectoryURL = storage.baseURL

                var args = ["-p", prompt, "--output-format", "json", "--no-session-persistence", "--dangerously-skip-permissions", "--model", "claude-\(ClaudeService.shared.selectedModel)-4-6"]
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
                        continuation.resume(throwing: ClaudeError.cliError("Exit \(process.terminationStatus): \(stderr)"))
                        return
                    }

                    let output = String(data: outData, encoding: .utf8) ?? ""

                    if let jsonData = output.data(using: .utf8),
                       let response = try? JSONDecoder().decode(CLIResponse.self, from: jsonData),
                       let result = response.result {
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
        let prompt: String
        if let question {
            prompt = "Analyze this command output and answer: \(question)\n\n```\n\(output.prefix(8000))\n```"
        } else {
            prompt = "Analyze this command output. Summarize key findings, highlight issues or anomalies, and suggest next steps if applicable:\n\n```\n\(output.prefix(8000))\n```"
        }
        return try await query(prompt, systemPrompt: "You are a CLI and devops expert. Analyze command output concisely. Use bullet points. Highlight errors, warnings, and anomalies.")
    }

    func explainError(_ command: String, stderr: String, exitCode: Int32) async throws -> String {
        let prompt = "Command: \(command)\nExit code: \(exitCode)\nError output:\n```\n\(stderr.prefix(4000))\n```\n\nExplain what went wrong and suggest a fix."
        return try await query(prompt, systemPrompt: "You are a CLI expert. Explain errors concisely and provide actionable fixes.")
    }

    func analyzeFile(at path: String, question: String? = nil) async throws -> String {
        let url = URL(fileURLWithPath: path)
        let content = try String(contentsOf: url, encoding: .utf8)
        let ext = url.pathExtension
        let prompt: String
        if let question {
            prompt = "Analyze this \(ext) file and answer: \(question)\n\n```\(ext)\n\(content.prefix(10000))\n```"
        } else {
            prompt = "Analyze this \(ext) file. Describe its purpose, highlight key patterns, potential issues, and suggest improvements:\n\n```\(ext)\n\(content.prefix(10000))\n```"
        }
        return try await query(prompt, systemPrompt: "You are a code and data analysis expert. Be concise and actionable.")
    }
}

enum ClaudeError: LocalizedError {
    case cliError(String)
    case notInstalled

    var errorDescription: String? {
        switch self {
        case .cliError(let msg): msg
        case .notInstalled: "Claude CLI not found at ~/.local/bin/claude. Install from https://claude.ai/code"
        }
    }
}
