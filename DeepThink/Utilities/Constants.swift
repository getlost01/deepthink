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
    static let homePath = "DeepThink"

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
        Bundle.main.resourceURL?
            .appendingPathComponent("deepthink-mcp").path
    }

    static var mcpBinaryPath: String {
        let candidates = [
            bundledMCPPath,
            localBin + "/deepthink-mcp",
            devCLIDir + "/out/deepthink-mcp"
        ].compactMap(\.self)
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
            ?? localBin + "/deepthink-mcp"
    }

    static var cliBinaryCandidates: [String] {
        var candidates: [String] = []
        if let bundled = bundledCLIPath { candidates.append(bundled) }
        candidates.append(contentsOf: [
            devCLIDir + "/deepthink",
            localBin + "/deepthink",
            "/usr/local/bin/deepthink"
        ])
        return candidates
    }
}
