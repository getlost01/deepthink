import SwiftUI

// MARK: - Thinking Indicator

struct ThinkingIndicator: View {
    let startTime: Date
    var useMCP: Bool = false
    @State private var elapsedSeconds: Int = 0
    @State private var rotation: Double = 0

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var label: String {
        useMCP ? "Using tools…" : "Thinking…"
    }

    private var elapsedText: String {
        if elapsedSeconds < 60 { return "(\(elapsedSeconds)s)" }
        return "(\(elapsedSeconds / 60)m \(elapsedSeconds % 60)s)"
    }

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            Text("✽")
                .font(.system(size: DS.IconSize.lg, weight: .medium))
                .foregroundStyle(DS.Colors.accent)
                .rotationEffect(.degrees(rotation))

            Text(label)
                .font(DS.Font.body)
                .foregroundStyle(DS.Colors.textSecondary)

            Text(elapsedText)
                .font(DS.Font.monoSmall)
                .foregroundStyle(DS.Colors.textTertiary)
                .contentTransition(.numericText())

            Spacer()
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
        .onAppear {
            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
        .onReceive(timer) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                elapsedSeconds = Int(Date().timeIntervalSince(startTime))
            }
        }
    }
}

// MARK: - Welcome Prompts

struct WelcomePrompts: View {
    let onSelect: (String) -> Void
    var noteCount: Int = 0
    var taskCount: Int = 0
    var pendingTaskCount: Int = 0
    var projectCount: Int = 0
    var knowledgeCount: Int = 0

    private let suggestions = [
        ("Summarize my recent notes", "doc.text.magnifyingglass"),
        ("What tasks need attention?", "exclamationmark.triangle"),
        ("Help me write a design doc", "pencil.and.outline"),
        ("Analyze my project progress", "chart.bar"),
        ("Search my knowledge base", "brain"),
        ("Break down a complex task", "list.bullet.indent")
    ]

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Hello"
        }
    }

    var body: some View {
        VStack(spacing: DS.Spacing.xxl) {
            VStack(spacing: DS.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(DS.Colors.accentFill)
                        .frame(width: 72, height: 72)
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                }

                Text(greeting)
                    .font(DS.Font.titleLarge)
                    .foregroundStyle(DS.Colors.textPrimary)

                Text("Your notes, tasks, and knowledge are always in context.")
                    .font(DS.Font.body)
                    .foregroundStyle(DS.Colors.textTertiary)
            }

            if noteCount > 0 || taskCount > 0 || knowledgeCount > 0 || projectCount > 0 {
                HStack(spacing: DS.Spacing.md) {
                    if projectCount > 0 {
                        welcomeStat(icon: "folder", value: "\(projectCount)", label: "projects")
                    }
                    if noteCount > 0 {
                        welcomeStat(icon: "doc.text", value: "\(noteCount)", label: "notes")
                    }
                    if taskCount > 0 {
                        welcomeStat(icon: "checklist", value: "\(taskCount)", label: "tasks")
                    }
                    if knowledgeCount > 0 {
                        welcomeStat(icon: "brain", value: "\(knowledgeCount)", label: "knowledge")
                    }
                    if pendingTaskCount > 0 {
                        welcomeStat(icon: "exclamationmark.circle", value: "\(pendingTaskCount)", label: "pending", color: DS.Colors.warning)
                    }
                }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: DS.Spacing.sm)], spacing: DS.Spacing.sm) {
                ForEach(suggestions, id: \.0) { title, icon in
                    SuggestionChip(title: title, icon: icon) { onSelect(title) }
                }
            }
            .frame(maxWidth: 600)
        }
        .frame(maxWidth: .infinity)
    }

    private func welcomeStat(icon: String, value: String, label: String, color: Color = DS.Colors.textSecondary) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: DS.IconSize.sm, weight: .medium))
                .foregroundStyle(color)
            Text(value)
                .font(DS.Font.caption)
                .fontWeight(.semibold)
                .foregroundStyle(DS.Colors.textPrimary)
            Text(label)
                .font(DS.Font.caption)
                .foregroundStyle(DS.Colors.textTertiary)
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
        .background(DS.Colors.fill, in: Capsule())
    }
}

// MARK: - Suggestion Chip

struct SuggestionChip: View {
    let title: String
    let icon: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: DS.IconSize.sm, weight: .semibold))
                    .foregroundStyle(DS.Colors.accent)
                Text(title)
                    .font(DS.Font.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(DS.Colors.textPrimary)
                    .lineLimit(1)
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm + 1)
            .background(
                isHovered ? DS.Colors.fillSecondary : DS.Colors.fill,
                in: RoundedRectangle(cornerRadius: DS.Radius.pill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.pill)
                    .strokeBorder(isHovered ? DS.Colors.borderHover : DS.Colors.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plainPointer)
        .onHover { isHovered = $0 }
        .animation(DS.Animation.quick, value: isHovered)
    }
}

// MARK: - Chat Content View

struct ChatContentView: View {
    let content: String

    private var isRichMarkdown: Bool {
        content.contains("```") || content.contains("| ") || content.contains("# ") ||
            content.contains("## ") || content.contains("- [") || content.contains("1. ") ||
            content.contains("> ") || content.contains("**")
    }

    var body: some View {
        if isRichMarkdown {
            ChatMarkdownView(markdown: content)
        } else if let attributed = try? AttributedString(
            markdown: content,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            Text(attributed)
                .font(DS.Font.body)
                .foregroundStyle(DS.Colors.textPrimary)
                .textSelection(.enabled)
                .lineSpacing(3)
        } else {
            Text(content)
                .font(DS.Font.body)
                .foregroundStyle(DS.Colors.textPrimary)
                .textSelection(.enabled)
                .lineSpacing(3)
        }
    }
}

// MARK: - Streaming Timer

struct StreamingTimer: View {
    let startTime: Date
    @State private var elapsed: Int = 0
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Text(elapsed < 60 ? "\(elapsed)s" : "\(elapsed / 60)m \(elapsed % 60)s")
            .font(DS.Font.monoSmall)
            .foregroundStyle(DS.Colors.textTertiary)
            .contentTransition(.numericText())
            .onReceive(timer) { _ in
                withAnimation(.easeInOut(duration: 0.3)) {
                    elapsed = Int(Date().timeIntervalSince(startTime))
                }
            }
    }
}

// MARK: - Streaming Asterisk

struct StreamingAsterisk: View {
    var showLabel: Bool = false
    @State private var rotation: Double = 0

    var body: some View {
        HStack(spacing: 4) {
            Text("✽")
                .font(.system(size: DS.IconSize.sm, weight: .medium))
                .foregroundStyle(DS.Colors.accent)
                .rotationEffect(.degrees(rotation))

            if showLabel {
                Text("Generating…")
                    .font(DS.Font.buttonSmall)
                    .foregroundStyle(DS.Colors.textTertiary)
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}

// MARK: - Chat Edit Button

struct ChatEditButton: View {
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "pencil")
                .font(.system(size: DS.IconSize.xs, weight: .medium))
                .foregroundStyle(isHovered ? DS.Colors.textPrimary : DS.Colors.textTertiary)
                .frame(width: 18, height: 18)
                .background(isHovered ? DS.Colors.fillSecondary : DS.Colors.fill, in: Circle())
                .overlay(Circle().strokeBorder(isHovered ? DS.Colors.borderHover : DS.Colors.transparent, lineWidth: 1))
        }
        .buttonStyle(.plainPointer)
        .onHover { isHovered = $0 }
        .animation(DS.Animation.quick, value: isHovered)
        .help("Edit message")
    }
}

// MARK: - Chat Action Button

struct ChatActionButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: DS.IconSize.xs, weight: .medium))
                Text(label)
                    .font(DS.Font.micro)
                    .fontWeight(.medium)
            }
            .foregroundStyle(isHovered ? DS.Colors.textPrimary : color)
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xs)
            .background(isHovered ? DS.Colors.fillSecondary : DS.Colors.fill, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.sm)
                    .strokeBorder(isHovered ? DS.Colors.borderHover : DS.Colors.transparent, lineWidth: 1)
            )
        }
        .buttonStyle(.plainPointer)
        .onHover { isHovered = $0 }
        .animation(DS.Animation.quick, value: isHovered)
    }
}

// MARK: - Scroll Offset Key

struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
