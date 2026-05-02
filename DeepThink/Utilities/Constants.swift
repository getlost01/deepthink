import Foundation
import SwiftUI

enum AppConstants {
    static let sidebarWidth: CGFloat = 220
    static let inspectorWidth: CGFloat = 280
    static let minWindowWidth: CGFloat = 1000
    static let minWindowHeight: CGFloat = 600
    static let commandPaletteWidth: CGFloat = 520
    static let commandPaletteMaxHeight: CGFloat = 400

    static let appName = "DeepThink"
    static let documentsPath = "DeepThink"

    static let fibonacciPoints = [0, 1, 2, 3, 5, 8, 13, 21]
    static let storyPointOptions = [1, 2, 3, 4, 5, 10, 15]
}

enum DeepThinkPaths {
    static let home = NSHomeDirectory()
    static let localBin = home + "/.local/bin"

    private static var projectDir: String {
        Bundle.main.bundlePath
            .components(separatedBy: "/DeepThink.app").first ?? ""
    }

    private static var devCLIDir: String {
        projectDir + "/cli"
    }

    static var bundledCLIPath: String? {
        Bundle.main.resourceURL?
            .appendingPathComponent("deepthink-cli").path
    }

    static var bundledMCPPath: String? {
        if let bundled = Bundle.main.resourceURL?
            .appendingPathComponent("mcp-server.ts").path,
           FileManager.default.fileExists(atPath: bundled) {
            return bundled
        }
        return nil
    }

    static var mcpServerPath: String {
        if let bundled = bundledMCPPath { return bundled }
        let devPath = devCLIDir + "/src/mcp-server.ts"
        if FileManager.default.fileExists(atPath: devPath) { return devPath }
        return localBin + "/deepthink-mcp-server.ts"
    }

    static var cliBinaryCandidates: [String] {
        var candidates: [String] = []
        if let bundled = bundledCLIPath { candidates.append(bundled) }
        candidates.append(contentsOf: [
            devCLIDir + "/deepthink",
            localBin + "/deepthink",
            "/usr/local/bin/deepthink",
        ])
        return candidates
    }

    static var cliInstallCandidates: [String] {
        var candidates: [String] = []
        if let bundled = bundledCLIPath { candidates.append(bundled) }
        candidates.append(contentsOf: [
            devCLIDir + "/out/deepthink",
            devCLIDir + "/deepthink",
        ])
        return candidates
    }
}
