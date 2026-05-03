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
    var autoSaveInterval: TimeInterval = 3

    @State private var mode: EditorMode = .rich
    @State private var autoSaveTask: Task<Void, Never>?
    @State private var lastSavedText: String = ""
    @State private var isDirty = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: DS.Spacing.sm) {
                HStack(spacing: 0) {
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
                            .foregroundStyle(mode == m ? DS.Colors.accent : DS.Colors.textTertiary)
                            .padding(.horizontal, DS.Spacing.md)
                            .padding(.vertical, DS.Spacing.xs + 2)
                            .background(mode == m ? DS.Colors.accentFill : .clear, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                        }
                        .buttonStyle(.plainPointer)
                    }
                }
                .padding(2)
                .background(DS.Colors.fill, in: RoundedRectangle(cornerRadius: DS.Radius.sm + 2))

                Spacer()

                HStack(spacing: DS.Spacing.xs) {
                    if isDirty {
                        Circle()
                            .fill(DS.Colors.warning)
                            .frame(width: 6, height: 6)
                        Text("Unsaved")
                            .font(DS.Font.small)
                            .foregroundStyle(DS.Colors.textTertiary)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(DS.Colors.success)
                        Text("Synced")
                            .font(DS.Font.small)
                            .foregroundStyle(DS.Colors.textTertiary)
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .background(DS.Colors.surfaceElevated)

            Divider()

            switch mode {
            case .rich:
                RichMarkdownEditor(text: $text)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            case .raw:
                RawMarkdownEditor(text: $text, placeholder: placeholder)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            }
        }
        .clipped()
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
                .font(DS.Font.mono)
                .scrollContentBackground(.hidden)
                .padding(DS.Spacing.md)

            if text.isEmpty {
                Text(placeholder)
                    .font(DS.Font.mono)
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

                DSSplitHandle(axis: .vertical)
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

// MARK: - Unified Split Handle

struct DSSplitHandle: View {
    enum Axis { case horizontal, vertical }
    var axis: Axis = .vertical
    @State private var isHovered = false

    var body: some View {
        ZStack {
            Rectangle()
                .fill(isHovered ? DS.Colors.borderHover : DS.Colors.border)
                .frame(
                    width: axis == .vertical ? 1 : nil,
                    height: axis == .horizontal ? 1 : nil
                )

            Capsule()
                .fill(isHovered ? DS.Colors.textTertiary : DS.Colors.borderHover)
                .frame(
                    width: axis == .vertical ? 4 : 36,
                    height: axis == .vertical ? 36 : 4
                )
        }
        .frame(
            width: axis == .vertical ? 8 : nil,
            height: axis == .horizontal ? 8 : nil
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
            if hovering {
                (axis == .vertical ? NSCursor.resizeLeftRight : NSCursor.resizeUpDown).push()
            } else {
                NSCursor.pop()
            }
        }
        .animation(DS.Animation.quick, value: isHovered)
    }
}
