import SwiftUI

enum EditorMode: String, CaseIterable {
    case rich = "Edit"
    case raw = "Raw"

    var icon: String {
        switch self {
        case .rich: "pencil"
        case .raw: "chevron.left.forwardslash.chevron.right"
        }
    }
}

struct MarkdownEditorWithToggle: View {
    @Binding var text: String
    var placeholder: String = "Start writing..."
    var onSave: (() -> Void)? = nil
    var autoSaveInterval: TimeInterval = 10

    @State private var mode: EditorMode = .rich
    @State private var autoSaveTask: Task<Void, Never>?
    @State private var lastSavedText: String = ""
    @State private var isDirty = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: DS.Spacing.xs) {
                ForEach(EditorMode.allCases, id: \.self) { m in
                    Button {
                        withAnimation(DS.Animation.quick) { mode = m }
                    } label: {
                        HStack(spacing: DS.Spacing.xs) {
                            Image(systemName: m.icon)
                                .font(.system(size: 9, weight: .medium))
                            Text(m.rawValue)
                                .font(DS.Font.small)
                                .fontWeight(.medium)
                        }
                        .foregroundStyle(mode == m ? .white : DS.Colors.textSecondary)
                        .padding(.horizontal, DS.Spacing.sm + 2)
                        .padding(.vertical, DS.Spacing.xs + 1)
                        .background(mode == m ? DS.Colors.accent : DS.Colors.fill, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                    }
                    .buttonStyle(.plainPointer)
                }

                Spacer()

                if isDirty {
                    HStack(spacing: DS.Spacing.xs) {
                        Circle()
                            .fill(DS.Colors.warning)
                            .frame(width: 6, height: 6)
                        Text("Unsaved")
                            .font(DS.Font.small)
                            .foregroundStyle(DS.Colors.textTertiary)
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .background(.bar)

            Divider()

            switch mode {
            case .rich:
                RichMarkdownEditor(text: $text)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .raw:
                RawMarkdownEditor(text: $text, placeholder: placeholder)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onChange(of: text) {
            isDirty = text != lastSavedText
            scheduleAutoSave()
        }
        .onAppear { lastSavedText = text }
        .onDisappear {
            autoSaveTask?.cancel()
            if isDirty { performSave() }
        }
    }

    private func scheduleAutoSave() {
        autoSaveTask?.cancel()
        autoSaveTask = Task {
            try? await Task.sleep(for: .seconds(autoSaveInterval))
            guard !Task.isCancelled else { return }
            await MainActor.run { performSave() }
        }
    }

    private func performSave() {
        onSave?()
        lastSavedText = text
        isDirty = false
    }
}

// MARK: - Raw Markdown Editor

struct RawMarkdownEditor: View {
    @Binding var text: String
    var placeholder: String

    var body: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $text)
                .font(.system(size: 13, weight: .regular, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(DS.Spacing.md)

            if text.isEmpty {
                Text(placeholder)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(DS.Colors.textTertiary)
                    .padding(DS.Spacing.md)
                    .padding(.leading, 5)
                    .padding(.top, 8)
                    .allowsHitTesting(false)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

// MARK: - Resizable Split

struct ResizableSplitView<Left: View, Right: View>: View {
    let left: Left
    let right: Right
    @State private var leftWidth: CGFloat = 320
    let minLeftWidth: CGFloat
    let minRightWidth: CGFloat

    init(
        minLeftWidth: CGFloat = 260,
        minRightWidth: CGFloat = 300,
        @ViewBuilder left: () -> Left,
        @ViewBuilder right: () -> Right
    ) {
        self.minLeftWidth = minLeftWidth
        self.minRightWidth = minRightWidth
        self.left = left()
        self.right = right()
    }

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                left
                    .frame(width: leftWidth)

                ResizeHandle()
                    .gesture(
                        DragGesture(minimumDistance: 1)
                            .onChanged { value in
                                let proposed = leftWidth + value.translation.width
                                let maxLeft = geo.size.width - minRightWidth
                                leftWidth = min(max(proposed, minLeftWidth), maxLeft)
                            }
                    )

                right
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

private struct ResizeHandle: View {
    @State private var isHovered = false

    var body: some View {
        Rectangle()
            .fill(isHovered ? DS.Colors.accent.opacity(0.5) : DS.Colors.border)
            .frame(width: isHovered ? 3 : 1)
            .contentShape(Rectangle().inset(by: -3))
            .onHover { hovering in
                isHovered = hovering
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
            .animation(DS.Animation.quick, value: isHovered)
    }
}
