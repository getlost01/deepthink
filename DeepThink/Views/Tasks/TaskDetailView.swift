import SwiftUI
import SwiftData

struct TaskDetailView: View {
    @Bindable var task: TaskItem
    @Query(filter: #Predicate<Project> { !$0.isArchived }) private var projects: [Project]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                TextField("Task title", text: $task.title)
                    .textFieldStyle(.plain)
                    .font(.title2)
                    .fontWeight(.semibold)

                Divider()

                HStack(spacing: 16) {
                    Picker("Status", selection: $task.status) {
                        ForEach(TaskStatus.allCases) { status in
                            Label(status.rawValue, systemImage: status.icon)
                                .tag(status)
                        }
                    }
                    .pickerStyle(.menu)

                    Picker("Priority", selection: $task.priority) {
                        ForEach(TaskPriority.allCases) { priority in
                            Label(priority.rawValue, systemImage: priority.icon)
                                .tag(priority)
                        }
                    }
                    .pickerStyle(.menu)
                }

                HStack(spacing: 16) {
                    Picker("Story Points", selection: Binding(
                        get: { task.storyPoints ?? -1 },
                        set: { task.storyPoints = $0 == -1 ? nil : $0 }
                    )) {
                        Text("None").tag(-1)
                        ForEach(AppConstants.fibonacciPoints, id: \.self) { point in
                            Text("\(point)").tag(point)
                        }
                    }
                    .pickerStyle(.menu)

                    DatePicker("Due Date",
                        selection: Binding(
                            get: { task.dueDate ?? Date() },
                            set: { task.dueDate = $0 }
                        ),
                        displayedComponents: .date
                    )

                    if task.dueDate != nil {
                        Button("Clear") { task.dueDate = nil }
                            .font(.caption)
                    }
                }

                Picker("Project", selection: Binding(
                    get: { task.project },
                    set: { task.project = $0 }
                )) {
                    Text("No Project").tag(nil as Project?)
                    ForEach(projects) { project in
                        HStack {
                            Circle()
                                .fill(Color(hex: project.color))
                                .frame(width: 8, height: 8)
                            Text(project.name)
                        }
                        .tag(project as Project?)
                    }
                }
                .pickerStyle(.menu)

                Divider()

                Text("Description")
                    .font(.headline)

                TextEditor(text: $task.detail)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 200)
                    .padding(8)
                    .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onChange(of: task.title) { task.modifiedAt = Date() }
        .onChange(of: task.detail) { task.modifiedAt = Date() }
        .onChange(of: task.statusRaw) { task.modifiedAt = Date() }
        .onChange(of: task.priorityRaw) { task.modifiedAt = Date() }
    }
}
