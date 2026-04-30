import Foundation

@Observable
final class CLIAnalysisService {
    static let shared = CLIAnalysisService()

    struct AnalysisResult: Identifiable {
        let id = UUID()
        let command: String
        let rawOutput: String
        let analysis: String
        let timestamp: Date
        let duration: TimeInterval
        let isError: Bool
    }

    var isRunning = false
    var results: [AnalysisResult] = []

    func runAndAnalyze(command: String, workingDirectory: String? = nil, question: String? = nil) async throws -> AnalysisResult {
        await MainActor.run { isRunning = true }
        let start = Date()

        do {
            let output = try await runCommand(command, workingDirectory: workingDirectory)
            let analysis = try await ClaudeService.shared.analyzeCLIOutput(output, question: question)
            let result = AnalysisResult(
                command: command,
                rawOutput: output,
                analysis: analysis,
                timestamp: Date(),
                duration: Date().timeIntervalSince(start),
                isError: false
            )
            await MainActor.run {
                results.insert(result, at: 0)
                isRunning = false
            }
            return result
        } catch {
            let result = AnalysisResult(
                command: command,
                rawOutput: "",
                analysis: "Error: \(error.localizedDescription)",
                timestamp: Date(),
                duration: Date().timeIntervalSince(start),
                isError: true
            )
            await MainActor.run {
                results.insert(result, at: 0)
                isRunning = false
            }
            return result
        }
    }

    func analyzeFile(at path: String, question: String? = nil) async throws -> AnalysisResult {
        await MainActor.run { isRunning = true }
        let start = Date()

        let analysis = try await ClaudeService.shared.analyzeFile(at: path, question: question)
        let result = AnalysisResult(
            command: "analyze: \(path)",
            rawOutput: "",
            analysis: analysis,
            timestamp: Date(),
            duration: Date().timeIntervalSince(start),
            isError: false
        )
        await MainActor.run {
            results.insert(result, at: 0)
            isRunning = false
        }
        return result
    }

    func analyzeURL(_ urlString: String, question: String? = nil) async throws -> AnalysisResult {
        await MainActor.run { isRunning = true }
        let start = Date()

        // Use curl to fetch URL content, then analyze
        let output = try await runCommand("curl -sL '\(urlString)' | head -500")
        let analysis = try await ClaudeService.shared.analyzeCLIOutput(
            output,
            question: question ?? "Analyze the content fetched from \(urlString)"
        )
        let result = AnalysisResult(
            command: "fetch: \(urlString)",
            rawOutput: output,
            analysis: analysis,
            timestamp: Date(),
            duration: Date().timeIntervalSince(start),
            isError: false
        )
        await MainActor.run {
            results.insert(result, at: 0)
            isRunning = false
        }
        return result
    }

    private func runCommand(_ command: String, workingDirectory: String? = nil) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/zsh")
                process.arguments = ["-l", "-c", command]
                if let dir = workingDirectory {
                    process.currentDirectoryURL = URL(fileURLWithPath: dir)
                }

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

                    let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
                    let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                    let stdout = String(data: outData, encoding: .utf8) ?? ""
                    let stderr = String(data: errData, encoding: .utf8) ?? ""

                    if process.terminationStatus != 0 && stdout.isEmpty {
                        continuation.resume(returning: "STDERR:\n\(stderr)")
                    } else {
                        let combined = stdout + (stderr.isEmpty ? "" : "\n\nSTDERR:\n\(stderr)")
                        continuation.resume(returning: combined)
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // Preset analysis commands
    static let presetCommands: [(name: String, command: String, icon: String, description: String)] = [
        ("Git Status", "git status && git log --oneline -10", "arrow.triangle.branch", "Current git status and recent commits"),
        ("Disk Usage", "df -h && du -sh * 2>/dev/null | sort -rh | head -20", "internaldrive", "Disk space and largest directories"),
        ("Running Processes", "ps aux --sort=-%mem | head -20", "cpu", "Top processes by memory usage"),
        ("Network Connections", "lsof -i -P -n | head -30", "network", "Active network connections"),
        ("Docker Status", "docker ps -a 2>/dev/null && docker images 2>/dev/null | head -20", "shippingbox", "Docker containers and images"),
        ("System Info", "sw_vers && sysctl -n machdep.cpu.brand_string && system_profiler SPMemoryDataType 2>/dev/null | head -10", "desktopcomputer", "macOS version, CPU, and memory"),
        ("NPM Audit", "npm audit 2>/dev/null || echo 'No package.json found'", "shield", "Check npm dependencies for vulnerabilities"),
        ("Brew Status", "brew outdated 2>/dev/null && brew doctor 2>/dev/null | head -20", "mug", "Homebrew outdated packages and health"),
    ]
}
