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
    weak var appState: AppState?

    private init() {}

    deinit { stop() }

    func configure(appState: AppState) {
        self.appState = appState
    }

    func presentSaveError(_ error: Error) {
        appState?.presentError(error, context: "Collector sync save")
    }

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
                syncSource(id: sourceID)
            } else {
                guard let interval = source.scheduleInterval, interval > 0 else { continue }
                let timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(interval), repeats: true) { [weak self] _ in
                    self?.syncSource(id: sourceID)
                }
                timers[sourceID] = timer
                if source.lastSyncAt.map({ Date().timeIntervalSince($0) > TimeInterval(interval) }) ?? true {
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

        Task {
            let sourceID = await MainActor.run { () -> PersistentIdentifier? in
                let context = ModelContext(container)
                let descriptor = FetchDescriptor<DataSource>(predicate: #Predicate<DataSource> { $0.id == id })
                return try? context.fetch(descriptor).first?.persistentModelID
            }
            guard let sourceID else { return }

            await DataCollectorService.shared.sync(sourceID: sourceID, container: container)

            await MainActor.run {
                activeSources[id] = Date()
            }
        }
    }

    func runNow(source: DataSource) {
        guard let container else { return }
        let sourceID = source.persistentModelID
        Task {
            await DataCollectorService.shared.sync(sourceID: sourceID, container: container)
            await MainActor.run {
                activeSources[source.id] = Date()
            }
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
