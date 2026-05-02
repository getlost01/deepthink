import SwiftData
import Foundation

@MainActor
let previewContainer: ModelContainer = {
    let schema = Schema([Note.self, TaskItem.self, Project.self, Tag.self, DataSource.self])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [config])

    let tag1 = Tag(name: "Swift", color: "#FF9500")
    let tag2 = Tag(name: "Design", color: "#AF52DE")
    let tag3 = Tag(name: "Bug", color: "#FF3B30")

    let project1 = Project(name: "DeepThink", summary: "AI productivity app for macOS", color: "#007AFF")
    let project2 = Project(name: "Website Redesign", summary: "Landing page refresh", color: "#34C759")

    let note1 = Note(title: "Architecture Notes", content: "# Architecture\n\nUsing SwiftUI + SwiftData for the frontend.\n\nKey decisions:\n- NavigationSplitView for 3-panel layout\n- Observable macro for state management\n- Local-first storage in ~/Documents/DeepThink/")
    note1.project = project1
    note1.tags = [tag1]

    let note2 = Note(title: "Design Principles", content: "## Design Principles\n\n1. Minimal and clean\n2. Keyboard-first\n3. Non-intrusive AI\n4. Fast and responsive")
    note2.tags = [tag2]
    note2.isPinned = true

    let note3 = Note(title: "Meeting Notes", content: "Discussed roadmap for Q3.\n\n- Phase 1: Core app shell\n- Phase 2: Terminal + markdown\n- Phase 3: AI features")

    let task1 = TaskItem(title: "Set up SwiftData models", status: .done, priority: .high)
    task1.storyPoints = 3
    task1.project = project1
    task1.tags = [tag1]

    let task2 = TaskItem(title: "Implement command palette", status: .inProgress, priority: .high)
    task2.storyPoints = 5
    task2.project = project1

    let task3 = TaskItem(title: "Design sidebar navigation", status: .done, priority: .medium)
    task3.storyPoints = 2
    task3.project = project1
    task3.tags = [tag2]

    let task4 = TaskItem(title: "Fix terminal output scrolling", status: .todo, priority: .medium)
    task4.storyPoints = 2
    task4.tags = [tag3]

    let task5 = TaskItem(title: "Add semantic search", status: .backlog, priority: .low)
    task5.storyPoints = 8

    for item in [tag1, tag2, tag3, project1, project2, note1, note2, note3, task1, task2, task3, task4, task5] as [any PersistentModel] {
        container.mainContext.insert(item)
    }

    return container
}()
