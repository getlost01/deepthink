import CoreServices
import Foundation
import SwiftData

@Observable
final class CollectorScheduler {
    static let shared = CollectorScheduler()

    var isRunning = false
    var activeSources: [UUID: Date] = [:]

    private var container: ModelContainer?
    private var timers: [UUID: Timer] = [:]
    private var watchers: [UUID: FolderWatcher] = [:]

    private init() {}

    deinit { stop() }

    func start(container: ModelContainer) {
        self.container = container
        isRunning = true
        refreshSchedules()
    }

    func stop() {
        isRunning = false
        timers.values.forEach { $0.invalidate() }
        timers.removeAll()
        watchers.values.forEach { $0.stop() }
        watchers.removeAll()
    }

    func refreshSchedules() {
        guard let container, isRunning else { return }

        timers.values.forEach { $0.invalidate() }
        timers.removeAll()
        watchers.values.forEach { $0.stop() }
        watchers.removeAll()

        let context = ModelContext(container)
        let descriptor = FetchDescriptor<DataSource>(predicate: #Predicate<DataSource> { $0.isEnabled })
        guard let sources = try? context.fetch(descriptor) else { return }

        for source in sources {
            let sourceID = source.id

            if source.type == .folder, let path = source.path {
                let watcher = FolderWatcher(path: path) { [weak self] in
                    self?.syncSource(id: sourceID)
                }
                watcher.start()
                watchers[sourceID] = watcher
                // Always run once at startup to catch changes since last session
                syncSource(id: sourceID)
            } else {
                guard let interval = source.scheduleInterval, interval > 0 else { continue }
                let timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(interval), repeats: true) { [weak self] _ in
                    self?.syncSource(id: sourceID)
                }
                timers[sourceID] = timer
                if source.lastSyncAt == nil || Date().timeIntervalSince(source.lastSyncAt!) > TimeInterval(interval) {
                    syncSource(id: sourceID)
                }
            }
        }

        StorageService.shared.writeLog(
            "Scheduled \(timers.count) recurring collector(s), \(watchers.count) folder watcher(s)",
            to: "collector"
        )
    }

    private func syncSource(id: UUID) {
        guard let container else { return }

        Task.detached(priority: .utility) { [weak self] in
            let context = ModelContext(container)
            let descriptor = FetchDescriptor<DataSource>(predicate: #Predicate<DataSource> { $0.id == id })
            guard let source = try? context.fetch(descriptor).first else { return }

            await DataCollectorService.shared.sync(source: source, container: container)

            try? context.save()
            await MainActor.run {
                self?.activeSources[id] = Date()
            }
        }
    }

    func runNow(source: DataSource) {
        guard let container else { return }
        Task {
            await DataCollectorService.shared.sync(source: source, container: container)
        }
    }
}

// MARK: - FSEvents folder watcher

private final class FolderWatcher {
    let path: String
    private let onChange: () -> Void
    private var stream: FSEventStreamRef?

    init(path: String, onChange: @escaping () -> Void) {
        self.path = path
        self.onChange = onChange
    }

    func start() {
        var ctx = FSEventStreamContext(version: 0, info: nil, retain: nil, release: nil, copyDescription: nil)
        ctx.info = Unmanaged.passUnretained(self).toOpaque()

        let cb: FSEventStreamCallback = { _, info, _, _, _, _ in
            guard let info else { return }
            Unmanaged<FolderWatcher>.fromOpaque(info).takeUnretainedValue().onChange()
        }

        guard let s = FSEventStreamCreate(
            nil, cb, &ctx,
            [path] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            2.0,
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagFileEvents)
        ) else { return }

        FSEventStreamScheduleWithRunLoop(s, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        FSEventStreamStart(s)
        stream = s
    }

    func stop() {
        guard let s = stream else { return }
        FSEventStreamStop(s)
        FSEventStreamInvalidate(s)
        FSEventStreamRelease(s)
        stream = nil
    }

    deinit { stop() }
}
