import Foundation
import SwiftData

@ModelActor
actor ArchiveActor {
    func run(autoArchiveTasks: Bool, threshold: Int) {
        let cutoff = Calendar.current.date(byAdding: .day, value: -threshold, to: Date()) ?? Date()

        if autoArchiveTasks {
            let doneTasks = (try? modelContext.fetch(
                FetchDescriptor<TaskItem>(predicate: #Predicate { $0.statusRaw == "done" && !$0.isArchived })
            )) ?? []
            for task in doneTasks {
                if let completedAt = task.completedAt, completedAt < cutoff {
                    task.isArchived = true
                    VectorStore.shared.enqueuePendingReindex(entryID: "task:\(task.id.uuidString)", entryType: "task")
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
                    VectorStore.shared.enqueuePendingReindex(entryID: "task:\(task.id.uuidString)", entryType: "task")
                }
            }
        }

        // Cascade archive state from project to tasks and notes
        let archivedProjects = (try? modelContext.fetch(
            FetchDescriptor<Project>(predicate: #Predicate { $0.isArchived })
        )) ?? []
        let archivedIDs = Set(archivedProjects.map(\.id))

        let activeTasks = (try? modelContext.fetch(
            FetchDescriptor<TaskItem>(predicate: #Predicate { !$0.isArchived })
        )) ?? []
        for task in activeTasks {
            if let project = task.project, archivedIDs.contains(project.id) {
                task.isArchived = true
                VectorStore.shared.enqueuePendingReindex(entryID: "task:\(task.id.uuidString)", entryType: "task")
            }
        }

        let activeNotes = (try? modelContext.fetch(
            FetchDescriptor<Note>(predicate: #Predicate { !$0.isArchived })
        )) ?? []
        for note in activeNotes {
            if let project = note.project, archivedIDs.contains(project.id) {
                note.isArchived = true
                VectorStore.shared.enqueuePendingReindex(entryID: "note:\(note.id.uuidString)", entryType: "note")
            }
        }

        // Cascade to subtasks of archived tasks
        let allArchived = (try? modelContext.fetch(
            FetchDescriptor<TaskItem>(predicate: #Predicate { $0.isArchived })
        )) ?? []
        for task in allArchived {
            for subtask in task.subtasks where !subtask.isArchived {
                subtask.isArchived = true
                VectorStore.shared.enqueuePendingReindex(entryID: "task:\(subtask.id.uuidString)", entryType: "task")
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
            VectorStore.shared.enqueuePendingReindex(entryID: "task:\(task.id.uuidString)", entryType: "task")
            for subtask in task.subtasks {
                subtask.isArchived = true
                VectorStore.shared.enqueuePendingReindex(entryID: "task:\(subtask.id.uuidString)", entryType: "task")
            }
        }
        for note in project.notes {
            note.isArchived = true
            VectorStore.shared.enqueuePendingReindex(entryID: "note:\(note.id.uuidString)", entryType: "note")
        }
        try? context.save()
    }

    static func unarchiveProjectTasks(_ project: Project, context: ModelContext) {
        let days = UserDefaults.standard.integer(forKey: "archiveDaysThreshold")
        let threshold = days > 0 ? days : 3
        let cutoff = Calendar.current.date(byAdding: .day, value: -threshold, to: Date()) ?? Date()
        for task in project.tasks {
            let isStale = task.status == .done && (task.completedAt.map { $0 < cutoff } ?? true)
            if !isStale {
                task.isArchived = false
                task.manuallyArchived = false
                VectorStore.shared.enqueuePendingReindex(entryID: "task:\(task.id.uuidString)", entryType: "task")
                for subtask in task.subtasks {
                    let subtaskStale = subtask.status == .done && (subtask.completedAt.map { $0 < cutoff } ?? true)
                    if !subtaskStale {
                        subtask.isArchived = false
                        subtask.manuallyArchived = false
                        VectorStore.shared.enqueuePendingReindex(entryID: "task:\(subtask.id.uuidString)", entryType: "task")
                    }
                }
            }
        }
        for note in project.notes {
            note.isArchived = false
            VectorStore.shared.enqueuePendingReindex(entryID: "note:\(note.id.uuidString)", entryType: "note")
        }
        try? context.save()
    }
}
