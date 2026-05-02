import Foundation

@Observable
final class DeepThinkCLIService {
    static let shared = DeepThinkCLIService()

    var isRunning = false
    var lastError: String?

    private let binaryPath: String

    struct CLIResult {
        let output: String
        let error: String
        let exitCode: Int32
        let success: Bool

        func decoded<T: Decodable>(_ type: T.Type) -> T? {
            guard success, let data = output.data(using: .utf8) else { return nil }
            return try? JSONDecoder().decode(type, from: data)
        }
    }

    struct CLIMemoryEntry: Codable {
        let id: String
        let content: String
        let tags: [String]
        let timestamp: String
        let layer: String
    }

    struct CLIMemoryRecall: Codable {
        let entries: [CLIMemoryEntry]
    }

    struct CLIMemoryStats: Codable {
        let shortTerm: Int
        let longTerm: Int
    }

    private init() {
        let candidates = DeepThinkPaths.cliBinaryCandidates
        self.binaryPath = candidates.first {
            FileManager.default.isExecutableFile(atPath: $0)
        } ?? candidates.last!
    }

    var isAvailable: Bool {
        FileManager.default.isExecutableFile(atPath: binaryPath)
    }

    // MARK: - Commands

    func status() async -> CLIResult {
        await run(["status"])
    }

    func analyze(file: String, withReport: Bool = false, title: String? = nil) async -> CLIResult {
        var args = ["analyze", file]
        if withReport { args.append("--report") }
        if let title { args.append(contentsOf: ["--title", title]) }
        return await run(args)
    }

    func analyzeQuick(file: String) async -> CLIResult {
        await run(["analyze", file, "--quick"])
    }

    func recall(query: String, json: Bool = false) async -> CLIResult {
        var args = ["memory", "recall", query]
        if json { args.append("--json") }
        return await run(args)
    }

    func remember(content: String, tags: [String] = [], layer: String = "short", json: Bool = false) async -> CLIResult {
        var args = ["memory", "save", content, "--layer", layer]
        if !tags.isEmpty {
            args.append(contentsOf: ["--tags", tags.joined(separator: ",")])
        }
        if json { args.append("--json") }
        return await run(args)
    }

    func memoryStats(json: Bool = false) async -> CLIResult {
        var args = ["memory"]
        if json { args.append("--json") }
        return await run(args)
    }

    func search(query: String, local: Bool = false, directory: String? = nil) async -> CLIResult {
        var args = ["search", query]
        if local {
            args.append("--local")
            if let dir = directory { args.append(contentsOf: ["--dir", dir]) }
        }
        return await run(args)
    }

    func ask(question: String, file: String? = nil, withMemory: Bool = false) async -> CLIResult {
        var args = ["ask", question]
        if let file { args.append(contentsOf: ["--file", file]) }
        if withMemory { args.append("--recall") }
        return await run(args)
    }

    func writeDocs(topic: String, input: String? = nil, output: String? = nil) async -> CLIResult {
        var args = ["write-docs", topic]
        if let input { args.append(contentsOf: ["--input", input]) }
        if let output { args.append(contentsOf: ["--output", output]) }
        return await run(args)
    }

    func runTask(_ task: String, noDocs: Bool = false) async -> CLIResult {
        var args = ["run"] + task.components(separatedBy: " ")
        if noDocs { args.append("--no-docs") }
        return await run(args)
    }

    // MARK: - Core Runner

    func run(_ args: [String]) async -> CLIResult {
        await MainActor.run { isRunning = true; lastError = nil }

        let result = await withCheckedContinuation { (continuation: CheckedContinuation<CLIResult, Never>) in
            DispatchQueue.global(qos: .userInitiated).async { [binaryPath] in
                let process = Process()
                process.executableURL = URL(fileURLWithPath: binaryPath)
                process.arguments = args

                var env = ProcessInfo.processInfo.environment
                env["HOME"] = NSHomeDirectory()
                env["PATH"] = "\(NSHomeDirectory())/.local/bin:/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:\(env["PATH"] ?? "")"
                if let apiKey = env["ANTHROPIC_API_KEY"] ?? ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] {
                    env["ANTHROPIC_API_KEY"] = apiKey
                }
                process.environment = env

                let outPipe = Pipe()
                let errPipe = Pipe()
                process.standardOutput = outPipe
                process.standardError = errPipe

                do {
                    try process.run()
                    process.waitUntilExit()

                    let stdout = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                    let stderr = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

                    continuation.resume(returning: CLIResult(
                        output: stdout.trimmingCharacters(in: .whitespacesAndNewlines),
                        error: stderr.trimmingCharacters(in: .whitespacesAndNewlines),
                        exitCode: process.terminationStatus,
                        success: process.terminationStatus == 0
                    ))
                } catch {
                    continuation.resume(returning: CLIResult(
                        output: "",
                        error: "Failed to launch CLI: \(error.localizedDescription)",
                        exitCode: -1,
                        success: false
                    ))
                }
            }
        }

        await MainActor.run {
            isRunning = false
            if !result.success { lastError = result.error }
        }

        return result
    }
}
