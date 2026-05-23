import AppKit
import Foundation
import SwiftUI

@MainActor
@Observable
final class UpdateService {
    static let shared = UpdateService()

    private static let repositoryURL = URL(string: "https://github.com/getlost01/deepthink")!
    private static let latestReleaseAPIURL = URL(string: "https://api.github.com/repos/getlost01/deepthink/releases/latest")!
    private static let fallbackReleasePageURL = URL(string: "https://github.com/getlost01/deepthink/releases/latest")!

    private var isCheckingGitHub = false
    private var hasCheckedAtLaunch = false

    private(set) var latestVersion: String?
    private(set) var latestReleaseURL: URL?
    private(set) var lastGitHubError: String?

    var isEmbedded: Bool {
        false
    }

    var canCheckForUpdates: Bool {
        !isCheckingGitHub
    }

    var isCheckingForUpdates: Bool {
        isCheckingGitHub
    }

    var currentVersion: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "0.0.0"
    }

    var hasUpdateAvailable: Bool {
        guard let latestVersion else { return false }
        return compareVersions(currentVersion, latestVersion) == .orderedAscending
    }

    private init() {}

    func prepareIfNeeded() {}

    func checkForUpdatesOnLaunchIfNeeded() {
        guard !hasCheckedAtLaunch else { return }
        hasCheckedAtLaunch = true
        checkForUpdates()
    }

    func checkForUpdates() {
        Task {
            await fetchLatestRelease()
        }
    }

    func openLatestReleaseDownload() {
        let url = latestReleaseURL ?? Self.fallbackReleasePageURL
        NSWorkspace.shared.open(url)
    }

    func openRepository() {
        NSWorkspace.shared.open(Self.repositoryURL)
    }

    private func fetchLatestRelease() async {
        guard !isCheckingGitHub else { return }
        isCheckingGitHub = true
        defer { isCheckingGitHub = false }
        lastGitHubError = nil

        var request = URLRequest(url: Self.latestReleaseAPIURL)
        request.timeoutInterval = 10
        request.setValue("DeepThinkApp", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                lastGitHubError = "Could not reach GitHub releases."
                return
            }

            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            latestVersion = normalizeVersionTag(release.tagName)
            latestReleaseURL = preferredDownloadURL(from: release)
        } catch {
            lastGitHubError = "Update check failed. Try again."
        }
    }

    private func preferredDownloadURL(from release: GitHubRelease) -> URL {
        if let macAsset = release.assets.first(where: { $0.browserDownloadURL.lastPathComponent == "DeepThink-macOS.zip" }) {
            return macAsset.browserDownloadURL
        }
        if let firstZip = release.assets.first(where: { $0.browserDownloadURL.pathExtension.lowercased() == "zip" }) {
            return firstZip.browserDownloadURL
        }
        return release.htmlURL
    }

    private func normalizeVersionTag(_ tag: String) -> String {
        var clean = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.lowercased().hasPrefix("v") { clean.removeFirst() }
        return clean
    }

    private func compareVersions(_ lhs: String, _ rhs: String) -> ComparisonResult {
        lhs.compare(rhs, options: .numeric)
    }
}

private struct GitHubRelease: Decodable {
    let tagName: String
    let htmlURL: URL
    let assets: [GitHubAsset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
        case assets
    }
}

private struct GitHubAsset: Decodable {
    let browserDownloadURL: URL

    enum CodingKeys: String, CodingKey {
        case browserDownloadURL = "browser_download_url"
    }
}
