import Foundation
import AppKit

struct BackupSnapshot: Codable, Identifiable, Equatable {
    var id: UUID
    var date: Date
    var sizeBytes: Int64
    var isManual: Bool
    var folderName: String

    var formattedSize: String {
        let mb = Double(sizeBytes) / 1_048_576
        if mb < 1 { return String(format: "%.0f KB", Double(sizeBytes) / 1024) }
        return String(format: "%.1f MB", mb)
    }
}

@Observable
final class BackupService {
    static let shared = BackupService()

    private let backupRoot: URL
    private let snapshotsDir: URL
    private let manifestURL: URL
    private let pendingRestoreURL: URL

    var snapshots: [BackupSnapshot] = []
    var isRunning = false
    var lastError: String?

    private var timer: Timer?

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        backupRoot = appSupport.appendingPathComponent("DeepThink/Backups")
        snapshotsDir = backupRoot.appendingPathComponent("snapshots")
        manifestURL = backupRoot.appendingPathComponent("manifest.json")
        pendingRestoreURL = backupRoot.appendingPathComponent("pending-restore.txt")

        try? FileManager.default.createDirectory(at: snapshotsDir, withIntermediateDirectories: true)
        loadSnapshots()
    }

    // MARK: - Launch hook — call BEFORE ModelContainer opens

    func applyPendingRestoreIfNeeded() {
        guard let folderName = try? String(contentsOf: pendingRestoreURL, encoding: .utf8)
                .trimmingCharacters(in: .whitespacesAndNewlines),
              !folderName.isEmpty
        else { return }

        let srcDir = snapshotsDir.appendingPathComponent(folderName)
        guard FileManager.default.fileExists(atPath: srcDir.path) else {
            try? FileManager.default.removeItem(at: pendingRestoreURL)
            return
        }

        do {
            try performRestore(from: srcDir)
            try? FileManager.default.removeItem(at: pendingRestoreURL)
        } catch {
            // Leave pending file; will retry next launch
        }
    }

    var canRestoreOnFirstLaunch: Bool {
        !FileManager.default.fileExists(atPath: StorageService.shared.storeURL.path) && !snapshots.isEmpty
    }

    // MARK: - Scheduler

    func start() {
        scheduleTimer()
    }

    // MARK: - Run Backup

    func runBackup(isManual: Bool = false) async {
        guard !isRunning else { return }
        await MainActor.run { isRunning = true; lastError = nil }

        let folderName = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let destDir = snapshotsDir.appendingPathComponent(folderName)

        do {
            try await Task.detached(priority: .utility) {
                try self.performBackup(to: destDir)
            }.value

            let size = await Task.detached(priority: .utility) {
                self.directorySize(at: destDir)
            }.value

            let snap = BackupSnapshot(
                id: UUID(), date: Date(),
                sizeBytes: size, isManual: isManual,
                folderName: folderName
            )

            // Mutate snapshots and prune entirely on MainActor to avoid data races
            let dirsToDelete: [URL] = await MainActor.run {
                self.snapshots.insert(snap, at: 0)
                self.isRunning = false

                let limit = UserDefaults.standard.object(forKey: "backupMaxKeep") as? Int ?? 10
                let autoSnaps = self.snapshots.filter { !$0.isManual }
                let excess = Array(autoSnaps.dropFirst(limit))
                for s in excess { self.snapshots.removeAll { $0.id == s.id } }
                self.saveManifest()
                return excess.map { self.snapshotsDir.appendingPathComponent($0.folderName) }
            }

            // Delete stale snapshot dirs off main thread
            for dir in dirsToDelete {
                try? FileManager.default.removeItem(at: dir)
            }
        } catch {
            try? FileManager.default.removeItem(at: destDir)
            await MainActor.run {
                self.lastError = error.localizedDescription
                self.isRunning = false
            }
        }
    }

    // MARK: - Stage Restore

    func stageRestore(snapshot: BackupSnapshot) {
        try? snapshot.folderName.write(to: pendingRestoreURL, atomically: true, encoding: .utf8)

        let alert = NSAlert()
        alert.messageText = "Restore Staged"
        alert.informativeText = "Quit DeepThink now to apply the restore from \(formattedDate(snapshot.date)). Your current workspace will be replaced on next launch."
        alert.addButton(withTitle: "Quit Now")
        alert.addButton(withTitle: "Later")
        alert.alertStyle = .warning
        if alert.runModal() == .alertFirstButtonReturn {
            NSApp.terminate(nil)
        }
    }

    // MARK: - Delete Snapshot

    func deleteSnapshot(_ snapshot: BackupSnapshot) {
        let dir = snapshotsDir.appendingPathComponent(snapshot.folderName)
        try? FileManager.default.removeItem(at: dir)
        snapshots.removeAll { $0.id == snapshot.id }
        saveManifest()
    }

    // MARK: - Private: Backup

    private func performBackup(to destDir: URL) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: destDir, withIntermediateDirectories: true)
        let base = StorageService.shared.baseURL

        let dataSrc = StorageService.shared.dataURL
        let dataDst = destDir.appendingPathComponent("data")
        if fm.fileExists(atPath: dataSrc.path) {
            try fm.copyItem(at: dataSrc, to: dataDst)
        }

        let subdirs: [(name: String, exclude: Set<String>)] = [
            (".claude", ["cache"]),
            ("knowledge", []),
            ("memory", []),
            ("workspace", []),
        ]

        for entry in subdirs {
            let src = base.appendingPathComponent(entry.name)
            let dst = destDir.appendingPathComponent(entry.name)
            guard fm.fileExists(atPath: src.path) else { continue }
            try copyDirectory(from: src, to: dst, excluding: entry.exclude)
        }
    }

    // MARK: - Private: Restore

    private func performRestore(from srcDir: URL) throws {
        let fm = FileManager.default
        let base = StorageService.shared.baseURL
        let tmp = base.deletingLastPathComponent()
            .appendingPathComponent("DeepThink.restore-tmp-\(Int(Date().timeIntervalSince1970))")

        if fm.fileExists(atPath: base.path) {
            try fm.moveItem(at: base, to: tmp)
        }

        do {
            try fm.createDirectory(at: base, withIntermediateDirectories: true)
            for subdir in ["data", ".claude", "knowledge", "memory", "workspace"] {
                let src = srcDir.appendingPathComponent(subdir)
                let dst = base.appendingPathComponent(subdir)
                if fm.fileExists(atPath: src.path) {
                    try fm.copyItem(at: src, to: dst)
                }
            }
            try? fm.removeItem(at: tmp)
        } catch {
            try? fm.removeItem(at: base)
            if fm.fileExists(atPath: tmp.path) {
                try? fm.moveItem(at: tmp, to: base)
            }
            throw error
        }
    }

    // MARK: - Private: File copy

    private func copyDirectory(from src: URL, to dst: URL, excluding: Set<String>) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: dst, withIntermediateDirectories: true)

        // Standardize to ensure no trailing slash skews dropFirst count
        let srcPath = src.standardized.path

        guard let enumerator = fm.enumerator(
            at: src,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: []
        ) else { return }

        for case let file as URL in enumerator {
            let filePath = file.standardized.path
            guard filePath.hasPrefix(srcPath) else { continue }
            let relPath = String(filePath.dropFirst(srcPath.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            guard !relPath.isEmpty else { continue }

            let topComponent = relPath.components(separatedBy: "/").first ?? ""
            if excluding.contains(topComponent) {
                let isDir = (try? file.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                if isDir { enumerator.skipDescendants() }
                continue
            }

            let dstFile = dst.appendingPathComponent(relPath)
            let isDir = (try? file.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false

            if isDir {
                try? fm.createDirectory(at: dstFile, withIntermediateDirectories: true)
            } else {
                try? fm.removeItem(at: dstFile)
                try fm.copyItem(at: file, to: dstFile)
            }
        }
    }

    // MARK: - Private: Scheduler

    private func scheduleTimer() {
        timer?.invalidate()

        // Use object(forKey:) so missing key falls back to true (enabled by default)
        let enabled = UserDefaults.standard.object(forKey: "backupEnabled") as? Bool ?? true
        guard enabled else { return }

        let hours = UserDefaults.standard.object(forKey: "backupIntervalHours") as? Int ?? 4
        let interval = TimeInterval(max(hours, 1) * 3600)

        if let last = snapshots.first?.date, Date().timeIntervalSince(last) >= interval {
            Task { await runBackup() }
        } else if snapshots.isEmpty {
            Task { await runBackup() }
        }

        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            let stillEnabled = UserDefaults.standard.object(forKey: "backupEnabled") as? Bool ?? true
            guard stillEnabled else { return }
            Task { await self?.runBackup() }
        }
    }

    // MARK: - Private: Manifest

    private func loadSnapshots() {
        guard let data = try? Data(contentsOf: manifestURL),
              let decoded = try? JSONDecoder().decode([BackupSnapshot].self, from: data)
        else { snapshots = []; return }
        snapshots = decoded.sorted { $0.date > $1.date }
    }

    private func saveManifest() {
        guard let data = try? JSONEncoder().encode(snapshots) else { return }
        try? data.write(to: manifestURL, options: .atomic)
    }

    // MARK: - Private: Helpers

    private func directorySize(at url: URL) -> Int64 {
        var total: Int64 = 0
        let keys: Set<URLResourceKey> = [.fileSizeKey, .isDirectoryKey]
        guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: Array(keys)) else { return 0 }
        for case let file as URL in enumerator {
            let vals = try? file.resourceValues(forKeys: keys)
            if vals?.isDirectory == true { continue }
            total += Int64(vals?.fileSize ?? 0)
        }
        return total
    }

    private func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: date)
    }
}
