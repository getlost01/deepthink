import Foundation
import SwiftData
import UserNotifications

@Observable
final class TaskNotificationService {
    static let shared = TaskNotificationService()

    private var container: ModelContainer?
    private var timer: Timer?
    private var authorized = false

    private init() {}

    deinit {
        timer?.invalidate()
    }

    func start(container: ModelContainer) {
        self.container = container
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, _ in
            self?.authorized = granted
            if granted { self?.scheduleCheck() }
        }
    }

    func checkAndNotify() {
        guard authorized, let container else { return }
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<TaskItem>(predicate: #Predicate<TaskItem> {
            !$0.isArchived && $0.statusRaw != "Done" && $0.statusRaw != "Cancelled"
        })
        guard let tasks = try? context.fetch(descriptor) else { return }

        let center = UNUserNotificationCenter.current()
        let today = Calendar.current.startOfDay(for: Date())
        guard let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) else { return }
        let todayStr = String(ISO8601DateFormatter().string(from: today).prefix(10))
        let notifiedKey = "notifiedTaskDay"
        let alreadyNotifiedToday = UserDefaults.standard.string(forKey: notifiedKey) == todayStr

        guard !alreadyNotifiedToday else { return }

        for task in tasks {
            guard let due = task.dueDate else { continue }
            let isDueToday = due >= today && due < tomorrow
            let isOverdue = due < today
            guard isDueToday || isOverdue else { continue }

            let id = "task-due-\(task.id.uuidString)"
            center.removePendingNotificationRequests(withIdentifiers: [id])

            let content = UNMutableNotificationContent()
            content.title = isOverdue ? "Overdue Task" : "Task Due Today"
            content.body = task.title
            content.sound = .default
            content.categoryIdentifier = "REMINDER"

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
            center.add(request, withCompletionHandler: nil)
        }

        UserDefaults.standard.set(String(todayStr), forKey: notifiedKey)
    }

    private func scheduleCheck() {
        checkAndNotify()

        let cal = Calendar.current
        guard let next9am = cal.nextDate(after: Date(), matching: DateComponents(hour: 9, minute: 0), matchingPolicy: .nextTime) else { return }
        let delay = next9am.timeIntervalSinceNow

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.checkAndNotify()
            self?.timer = Timer.scheduledTimer(withTimeInterval: 86400, repeats: true) { [weak self] _ in
                self?.checkAndNotify()
            }
        }
    }
}
