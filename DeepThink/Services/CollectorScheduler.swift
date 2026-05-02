import Foundation
import SwiftData

@Observable
final class CollectorScheduler {
    static let shared = CollectorScheduler()

    var isRunning = false
    var activeSources: [UUID: Date] = [:]

    private var container: ModelContainer?
    private var timers: [UUID: Timer] = [:]

    private init() {}

    func start(container: ModelContainer) {
        self.container = container
        isRunning = true
        refreshSchedules()
    }

    func stop() {
        isRunning = false
        timers.values.forEach { $0.invalidate() }
        timers.removeAll()
    }

    func refreshSchedules() {
        guard let container, isRunning else { return }

        timers.values.forEach { $0.invalidate() }
        timers.removeAll()

        let context = ModelContext(container)
        let descriptor = FetchDescriptor<DataSource>(predicate: #Predicate<DataSource> { $0.isEnabled })
        guard let sources = try? context.fetch(descriptor) else { return }

        for source in sources {
            guard let interval = source.scheduleInterval, interval > 0 else { continue }

            let sourceID = source.id
            let timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(interval), repeats: true) { [weak self] _ in
                self?.syncSource(id: sourceID)
            }
            timers[source.id] = timer

            // Run immediately if never synced or last sync was longer ago than interval
            if source.lastSyncAt == nil || Date().timeIntervalSince(source.lastSyncAt!) > TimeInterval(interval) {
                syncSource(id: sourceID)
            }
        }

        StorageService.shared.writeLog("Scheduled \(timers.count) recurring collector(s)", to: "collector")
    }

    private func syncSource(id: UUID) {
        guard let container else { return }

        DispatchQueue.global(qos: .utility).async {
            let context = ModelContext(container)
            let descriptor = FetchDescriptor<DataSource>(predicate: #Predicate<DataSource> { $0.id == id })
            guard let source = try? context.fetch(descriptor).first else { return }

            Task {
                await DataCollectorService.shared.sync(source: source, container: container)

                await MainActor.run {
                    self.activeSources[id] = Date()
                    try? context.save()
                }
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
