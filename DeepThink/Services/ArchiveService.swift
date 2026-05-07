import Foundation
import SwiftData

@ModelActor
actor ArchiveActor {
    func run(autoArchiveTasks: Bool, threshold: Int) {
        let cutoff = Calendar.current.date(byAdding: .day, value: -threshold, to: Date())!

        if autoArchiveTasks {
            let doneTasks = (try? modelContext.fetch(
                FetchDescriptor<TaskItem>(predicate: #Predicate { $0.statusRaw == "done" && !$0.isArchived })
            )) ?? []
            for task in doneTasks {
                if let completedAt = task.completedAt, completedAt < cutoff {
                    task.isArchived = true
                }
            }

            // Only un-archive tasks not manually archived by user
            let autoArchivedTasks = (try? modelContext.fetch(
                FetchDescriptor<TaskItem>(predicate: #Predicate { $0.isArchived && $0.statusRaw == "done" && !$0.manuallyArchived })
            )) ?? []
            for task in autoArchivedTasks {
                guard !(task.project?.isArchived ?? false) else { continue }
                if let completedAt = task.completedAt, completedAt >= cutoff {
                    task.isArchived = false
                }
            }
        }

        // Cascade archive state from project to tasks and notes
        let archivedProjects = (try? modelContext.fetch(
            FetchDescriptor<Project>(predicate: #Predicate { $0.isArchived })
        )) ?? []
        let archivedIDs = Set(archivedProjects.map(\.persistentModelID))

        let activeTasks = (try? modelContext.fetch(
            FetchDescriptor<TaskItem>(predicate: #Predicate { !$0.isArchived })
        )) ?? []
        for task in activeTasks {
            if let project = task.project, archivedIDs.contains(project.persistentModelID) {
                task.isArchived = true
            }
        }

        let activeNotes = (try? modelContext.fetch(
            FetchDescriptor<Note>(predicate: #Predicate { !$0.isArchived })
        )) ?? []
        for note in activeNotes {
            if let project = note.project, archivedIDs.contains(project.persistentModelID) {
                note.isArchived = true
            }
        }

        // Cascade to subtasks of archived tasks
        let allArchived = (try? modelContext.fetch(
            FetchDescriptor<TaskItem>(predicate: #Predicate { $0.isArchived })
        )) ?? []
        for task in allArchived {
            for subtask in task.subtasks where !subtask.isArchived {
                subtask.isArchived = true
            }
        }

        try? modelContext.save()
    }
}

@Observable
final class ArchiveService {
    static let shared = ArchiveService()

    func start(container: ModelContainer) {
        Task { await run(container: container) }
    }

    func triggerRun(container: ModelContainer) {
        Task { await run(container: container) }
    }

    private func run(container: ModelContainer) async {
        let actor = ArchiveActor(modelContainer: container)
        let ud = UserDefaults.standard
        let autoArchiveTasks = ud.object(forKey: "autoArchiveTasks") as? Bool ?? true
        let days = ud.integer(forKey: "archiveDaysThreshold")
        let threshold = days > 0 ? days : 3
        await actor.run(autoArchiveTasks: autoArchiveTasks, threshold: threshold)
    }

    static func archiveProjectTasks(_ project: Project, context: ModelContext) {
        for task in project.tasks {
            task.isArchived = true
            for subtask in task.subtasks { subtask.isArchived = true }
        }
        for note in project.notes { note.isArchived = true }
        try? context.save()
    }

    static func unarchiveProjectTasks(_ project: Project, context: ModelContext) {
        let days = UserDefaults.standard.integer(forKey: "archiveDaysThreshold")
        let threshold = days > 0 ? days : 3
        let cutoff = Calendar.current.date(byAdding: .day, value: -threshold, to: Date())!
        for task in project.tasks {
            let isStale = task.status == .done && (task.completedAt.map { $0 < cutoff } ?? true)
            if !isStale {
                task.isArchived = false
                task.manuallyArchived = false
                for subtask in task.subtasks {
                    let subtaskStale = subtask.status == .done && (subtask.completedAt.map { $0 < cutoff } ?? true)
                    if !subtaskStale {
                        subtask.isArchived = false
                        subtask.manuallyArchived = false
                    }
                }
            }
        }
        for note in project.notes { note.isArchived = false }
        try? context.save()
    }
}
