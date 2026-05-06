import SwiftUI
import SwiftData

struct QuickCaptureView: View {
    let onDismiss: () -> Void
    let modelContainer: ModelContainer

    @State private var captureType: CaptureType = .knowledge
    @State private var title = ""
    @State private var content = ""
    @State private var tags = ""
    @State private var selectedProjectName: String?
    @State private var selectedBucket: String = "General"
    @State private var saved = false
    @State private var projects: [Project] = []
    @FocusState private var titleFocused: Bool

    enum CaptureType: String, CaseIterable {
        case knowledge = "Knowledge"
        case note = "Note"
        case task = "Task"

        var icon: String {
            switch self {
            case .knowledge: "brain"
            case .note: "doc.text"
            case .task: "checklist"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Rectangle().fill(DS.Colors.borderHover).frame(height: 0.5)
            contentArea
            Rectangle().fill(DS.Colors.borderHover).frame(height: 0.5)
            footer
        }
        .frame(width: 720, height: 620)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl))
        .background(DS.Colors.surfaceElevated, in: RoundedRectangle(cornerRadius: DS.Radius.xl))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.xl)
                .strokeBorder(DS.Colors.borderHover, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.35), radius: 30, y: 10)
        .shadow(color: .black.opacity(0.12), radius: 2, y: 1)
        .onAppear {
            titleFocused = true
            loadProjects()
        }
        .onReceive(NotificationCenter.default.publisher(for: .quickCaptureReset)) { _ in
            resetForm()
        }
        .onReceive(NotificationCenter.default.publisher(for: .quickCapturePrefill)) { notification in
            if let prefillContent = notification.userInfo?["content"] as? String {
                content = prefillContent
                title = String(prefillContent.prefix(60)).components(separatedBy: "\n").first ?? "AI Response"
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: DS.Spacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: DS.Radius.sm)
                    .fill(DS.Colors.accentFill)
                    .frame(width: 26, height: 26)
                Image(systemName: "bolt.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DS.Colors.accent)
            }

            Text("Quick Capture")
                .font(DS.Font.heading)
                .foregroundStyle(DS.Colors.textPrimary)

            Spacer()

            typePicker
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
        .background(DragHandle())
    }

    private var typePicker: some View {
        HStack(spacing: DS.Spacing.xxs) {
            ForEach(CaptureType.allCases, id: \.self) { type in
                Button {
                    withAnimation(DS.Animation.quick) { captureType = type }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: type.icon)
                            .font(.system(size: DS.IconSize.xs, weight: .semibold))
                        Text(type.rawValue)
                            .font(DS.Font.small)
                            .fontWeight(captureType == type ? .semibold : .medium)
                    }
                    .foregroundStyle(captureType == type ? DS.Colors.accent : DS.Colors.textSecondary)
                    .padding(.horizontal, DS.Spacing.sm + 2)
                    .padding(.vertical, 5)
                    .contentShape(Rectangle())
                    .background(
                        captureType == type
                            ? AnyShapeStyle(DS.Colors.accentFill)
                            : AnyShapeStyle(.clear),
                        in: RoundedRectangle(cornerRadius: DS.Radius.sm)
                    )
                }
                .buttonStyle(.plainPointer)
            }
        }
        .padding(3)
        .background(DS.Colors.fillSecondary, in: RoundedRectangle(cornerRadius: DS.Radius.md))
    }

    // MARK: - Content

    private var contentArea: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text("TITLE")
                    .font(DS.Font.small)
                    .foregroundStyle(DS.Colors.textTertiary)
                    .textCase(.uppercase)

                TextField("Enter a title...", text: $title)
                    .textFieldStyle(.plain)
                    .font(DS.Font.body)
                    .focused($titleFocused)
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.md)
                    .background(DS.Colors.fillSecondary, in: RoundedRectangle(cornerRadius: DS.Radius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.md)
                            .strokeBorder(DS.Colors.border, lineWidth: 1)
                    )
            }

            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text("CONTENT")
                    .font(DS.Font.small)
                    .foregroundStyle(DS.Colors.textTertiary)
                    .textCase(.uppercase)

                MarkdownEditorWithToggle(text: $content, placeholder: "Start writing...")
                    .frame(maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.md)
                            .strokeBorder(DS.Colors.border, lineWidth: 1)
                    )
            }

            HStack(spacing: DS.Spacing.sm) {
                switch captureType {
                case .note, .task:
                    projectChip
                case .knowledge:
                    bucketChip
                    tagsChip
                }
                Spacer()
            }
            .animation(DS.Animation.quick, value: captureType)
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.lg)
    }

    private var projectChip: some View {
        Menu {
            Button { selectedProjectName = nil } label: { Text("None") }
            Divider()
            ForEach(projects, id: \.name) { project in
                Button {
                    selectedProjectName = project.name
                } label: {
                    Label(project.name, systemImage: "folder")
                }
            }
        } label: {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "folder")
                    .font(.system(size: DS.IconSize.sm))
                    .foregroundStyle(selectedProjectName != nil ? DS.Colors.accent : DS.Colors.textSecondary)
                Text(selectedProjectName ?? "Project")
            }
            .font(DS.Font.caption)
            .padding(.horizontal, DS.Spacing.sm + 2)
            .padding(.vertical, DS.Spacing.xs + 2)
            .background(DS.Colors.fillSecondary, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
        }
        .buttonStyle(.plainPointer)
    }

    private var bucketChip: some View {
        Menu {
            ForEach(KnowledgeService.shared.buckets, id: \.self) { bucket in
                Button {
                    selectedBucket = bucket
                } label: {
                    Label(bucket, systemImage: "archivebox")
                }
            }
        } label: {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "archivebox")
                    .font(.system(size: DS.IconSize.sm))
                    .foregroundStyle(DS.Colors.textSecondary)
                Text(selectedBucket)
            }
            .font(DS.Font.caption)
            .padding(.horizontal, DS.Spacing.sm + 2)
            .padding(.vertical, DS.Spacing.xs + 2)
            .background(DS.Colors.fillSecondary, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
        }
        .buttonStyle(.plainPointer)
    }

    private var tagsChip: some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: "tag")
                .font(.system(size: DS.IconSize.sm))
                .foregroundStyle(DS.Colors.textTertiary)
            TextField("Tags (comma separated)", text: $tags)
                .textFieldStyle(.plain)
                .font(DS.Font.caption)
        }
        .padding(.horizontal, DS.Spacing.sm + 2)
        .padding(.vertical, DS.Spacing.xs + 2)
        .background(DS.Colors.fillSecondary, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: DS.Spacing.sm) {
            Text("\u{2325}Space to toggle  \u{00b7}  Esc to close")
                .font(DS.Font.micro)
                .foregroundStyle(DS.Colors.textTertiary)

            Spacer()

            if saved {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(DS.Colors.success)
                    Text("Saved!")
                        .font(DS.Font.small)
                        .fontWeight(.semibold)
                        .foregroundStyle(DS.Colors.success)
                }
                .transition(.scale.combined(with: .opacity))
            } else {
                Button("Cancel") { onDismiss() }
                    .buttonStyle(DSSecondaryButtonStyle())
                    .keyboardShortcut(.escape, modifiers: [])

                Button {
                    save()
                } label: {
                    HStack(spacing: 4) {
                        Text("Save")
                        Text("\u{2318}\u{21a9}")
                            .font(DS.Font.micro)
                            .opacity(0.7)
                    }
                }
                .buttonStyle(DSPrimaryButtonStyle())
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(!canSave)
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
    }

    // MARK: - Logic

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func loadProjects() {
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<Project>(sortBy: [SortDescriptor(\.name)])
        projects = (try? context.fetch(descriptor)) ?? []
    }

    private func resetForm() {
        title = ""
        content = ""
        tags = ""
        selectedProjectName = nil
        selectedBucket = "General"
        saved = false
    }

    private func save() {
        let resolvedTitle = title.trimmingCharacters(in: .whitespaces).isEmpty
            ? "Quick capture \(Date().formatted(date: .abbreviated, time: .shortened))"
            : title.trimmingCharacters(in: .whitespaces)

        switch captureType {
        case .note:
            let context = ModelContext(modelContainer)
            let note = Note(title: resolvedTitle, content: content)
            if let projectName = selectedProjectName {
                let desc = FetchDescriptor<Project>(predicate: #Predicate { $0.name == projectName })
                note.project = try? context.fetch(desc).first
            }
            context.insert(note)
            try? context.save()

        case .knowledge:
            let tagList = tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            KnowledgeService.shared.createEntry(
                title: resolvedTitle,
                content: content,
                source: "manual",
                tags: tagList,
                bucket: selectedBucket
            )

        case .task:
            let context = ModelContext(modelContainer)
            let task = TaskItem(title: resolvedTitle, detail: content)
            if let projectName = selectedProjectName {
                let desc = FetchDescriptor<Project>(predicate: #Predicate { $0.name == projectName })
                task.project = try? context.fetch(desc).first
            }
            context.insert(task)
            try? context.save()
        }

        withAnimation(.spring(duration: 0.3)) { saved = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            resetForm()
            QuickCaptureWindowController.shared.resetAndDismiss()
        }
    }
}

// MARK: - Window Drag Handle

private struct DragHandle: NSViewRepresentable {
    func makeNSView(context: Context) -> DragHandleView { DragHandleView() }
    func updateNSView(_ nsView: DragHandleView, context: Context) {}
}

private class DragHandleView: NSView {
    override var mouseDownCanMoveWindow: Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}
