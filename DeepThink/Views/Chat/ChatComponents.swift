import SwiftUI

// MARK: - Thinking Indicator

struct ThinkingIndicator: View {
    let startTime: Date
    var useMCP: Bool = false
    @State private var elapsedSeconds: Int = 0
    @State private var pulse = false

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var label: String {
        useMCP ? "Using tools..." : "Thinking..."
    }

    private var elapsedText: String {
        if elapsedSeconds < 60 { return "\(elapsedSeconds)s" }
        return "\(elapsedSeconds / 60)m \(elapsedSeconds % 60)s"
    }

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: useMCP ? "wrench.and.screwdriver" : "sparkles")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DS.Colors.accent)
                .opacity(pulse ? 0.4 : 1.0)

            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(DS.Colors.textSecondary)

            Text(elapsedText)
                .font(DS.Font.monoSmall)
                .foregroundStyle(DS.Colors.textTertiary)
                .contentTransition(.numericText())

            Spacer()
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
        .background(DS.Colors.fillSecondary, in: RoundedRectangle(cornerRadius: 10))
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                pulse = true
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

    private let suggestions = [
        ("Summarize my recent notes", "doc.text.magnifyingglass"),
        ("What tasks need attention?", "exclamationmark.triangle"),
        ("Help me write a design doc", "pencil.and.outline"),
        ("Analyze my project progress", "chart.bar"),
        ("Search my knowledge base", "brain"),
        ("Break down a complex task", "list.bullet.indent"),
    ]

    var body: some View {
        VStack(spacing: DS.Spacing.xxl) {
            VStack(spacing: DS.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(DS.Colors.accent.opacity(0.08))
                        .frame(width: 64, height: 64)
                    Circle()
                        .fill(DS.Colors.accent.opacity(0.12))
                        .frame(width: 48, height: 48)
                    Image(systemName: "sparkles")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(DS.Colors.accent)
                }

                Text("How can I help?")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(DS.Colors.textPrimary)

                Text("Your notes, tasks, and knowledge are always in context.")
                    .font(DS.Font.body)
                    .foregroundStyle(DS.Colors.textTertiary)
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
                    .font(.system(size: 10, weight: .semibold))
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
                in: RoundedRectangle(cornerRadius: 20)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
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
        content.contains("```") || content.contains("| ") || content.contains("# ") || content.contains("## ")
    }

    var body: some View {
        if isRichMarkdown {
            ChatMarkdownView(markdown: content)
        } else if let attributed = try? AttributedString(
            markdown: content,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            Text(attributed)
                .font(.system(size: 13))
                .foregroundStyle(DS.Colors.textPrimary)
                .textSelection(.enabled)
                .lineSpacing(3)
        } else {
            Text(content)
                .font(.system(size: 13))
                .foregroundStyle(DS.Colors.textPrimary)
                .textSelection(.enabled)
                .lineSpacing(3)
        }
    }
}

// MARK: - Scroll Offset Key

struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
