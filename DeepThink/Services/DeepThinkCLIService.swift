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
    }

    private init() {
        // Priority: 1) App bundle  2) Dev source tree  3) Home directory
        let bundled = Bundle.main.resourceURL?
            .appendingPathComponent("deepthink-cli").path ?? ""

        let projectDir = Bundle.main.bundlePath
            .components(separatedBy: "/DeepThink.app").first ?? ""

        let candidates = [
            bundled,
            projectDir + "/cli/deepthink",
            NSHomeDirectory() + "/code/deepthink/cli/deepthink",
            "/usr/local/bin/deepthink",
        ]

        self.binaryPath = candidates.first {
            FileManager.default.isExecutableFile(atPath: $0)
        } ?? candidates[2]
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

    func recall(query: String) async -> CLIResult {
        await run(["recall", query])
    }

    func remember(content: String, tags: [String] = [], layer: String = "short") async -> CLIResult {
        var args = ["remember", content, "--layer", layer]
        if !tags.isEmpty {
            args.append(contentsOf: ["--tags", tags.joined(separator: ",")])
        }
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

    func memoryStats() async -> CLIResult {
        await run(["memory"])
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
