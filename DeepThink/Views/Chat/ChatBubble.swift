import SwiftUI

struct ChatBubble: View {
    let message: AIMessage
    var onRetry: (() -> Void)? = nil
    var onEdit: ((String) -> Void)? = nil
    var onSaveAsNote: ((String) -> Void)? = nil
    var onCreateTask: ((String) -> Void)? = nil
    @State private var copied = false
    @State private var isEditing = false
    @State private var editText = ""
    @State private var isHovered = false

    var body: some View {
        if message.role == .user {
            userBubble
        } else if message.role == .error {
            errorBubble
        } else {
            assistantBubble
        }
    }

    private var userBubble: some View {
        HStack {
            Spacer(minLength: 120)

            if isEditing {
                VStack(alignment: .trailing, spacing: DS.Spacing.xs) {
                    TextField("Edit message...", text: $editText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .lineLimit(2...6)
                        .font(DS.Font.body)
                        .padding(.horizontal, DS.Spacing.lg)
                        .padding(.vertical, DS.Spacing.md)
                        .background(DS.Colors.accent.opacity(DS.Opacity.hover), in: RoundedRectangle(cornerRadius: DS.Radius.xl))
                        .overlay(RoundedRectangle(cornerRadius: DS.Radius.xl).strokeBorder(DS.Colors.accent.opacity(0.25), lineWidth: 1))

                    HStack(spacing: DS.Spacing.sm) {
                        Button {
                            isEditing = false
                        } label: {
                            Text("Cancel")
                                .font(DS.Font.buttonSmall)
                                .foregroundStyle(DS.Colors.textTertiary)
                        }
                        .buttonStyle(.plainPointer)

                        Button {
                            isEditing = false
                            onEdit?(editText)
                        } label: {
                            Text("Send")
                                .font(DS.Font.buttonSmall)
                                .fontWeight(.semibold)
                                .foregroundStyle(DS.Colors.onAccent)
                                .padding(.horizontal, DS.Spacing.sm)
                                .padding(.vertical, 3)
                                .background(DS.Colors.accent, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                        }
                        .buttonStyle(.plainPointer)
                    }
                }
            } else {
                HStack(spacing: DS.Spacing.xs) {
                    if isHovered && onEdit != nil {
                        Button {
                            editText = message.content
                            isEditing = true
                        } label: {
                            Image(systemName: "pencil")
                                .font(.system(size: DS.IconSize.sm, weight: .medium))
                                .foregroundStyle(DS.Colors.textTertiary)
                                .frame(width: DS.IconSize.xxl, height: DS.IconSize.xxl)
                                .background(DS.Colors.fill, in: Circle())
                        }
                        .buttonStyle(.plainPointer)
                        .help("Edit message")
                        .transition(.opacity)
                    }

                    Text(message.content)
                        .font(DS.Font.body)
                        .foregroundStyle(DS.Colors.textPrimary)
                        .textSelection(.enabled)
                        .padding(.horizontal, DS.Spacing.lg)
                        .padding(.vertical, DS.Spacing.md)
                        .frame(maxWidth: 560, alignment: .trailing)
                        .background(DS.Colors.accent.opacity(DS.Opacity.hover), in: RoundedRectangle(cornerRadius: DS.Radius.xl))
                        .overlay(RoundedRectangle(cornerRadius: DS.Radius.xl).strokeBorder(DS.Colors.accent.opacity(DS.Opacity.subtle), lineWidth: 1))
                }
            }
        }
        .padding(.horizontal, DS.Spacing.xl)
        .padding(.vertical, DS.Spacing.sm)
        .onHover { isHovered = $0 }
        .animation(DS.Animation.quick, value: isHovered)
    }

    private var assistantBubble: some View {
        HStack(alignment: .top, spacing: DS.Spacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(
                        LinearGradient(
                            colors: [DS.Colors.accent.opacity(0.14), DS.Colors.accent.opacity(0.06)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: DS.IconSize.xxl, height: DS.IconSize.xxl)
                Image(systemName: "sparkles")
                    .font(.system(size: DS.IconSize.sm, weight: .semibold))
                    .foregroundStyle(DS.Colors.accent)
            }
            .padding(.top, DS.Spacing.md)

            VStack(alignment: .leading, spacing: 0) {
                ChatContentView(content: message.content)
                    .padding(DS.Spacing.md)

                HStack(spacing: DS.Spacing.sm) {
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(message.content, forType: .string)
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                .font(.system(size: DS.IconSize.xs, weight: .medium))
                            Text(copied ? "Copied" : "Copy")
                                .font(DS.Font.buttonSmall)
                        }
                        .foregroundStyle(copied ? DS.Colors.success : DS.Colors.textTertiary)
                    }
                    .buttonStyle(.plainPointer)

                    if let onSaveAsNote {
                        Button {
                            onSaveAsNote(message.content)
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "doc.text.badge.plus")
                                    .font(.system(size: DS.IconSize.xs, weight: .medium))
                                Text("Save as Note")
                                    .font(DS.Font.buttonSmall)
                            }
                            .foregroundStyle(DS.Colors.textTertiary)
                        }
                        .buttonStyle(.plainPointer)
                    }

                    if let onCreateTask {
                        Button {
                            onCreateTask(message.content)
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "checklist.checked")
                                    .font(.system(size: DS.IconSize.xs, weight: .medium))
                                Text("Create Task")
                                    .font(DS.Font.buttonSmall)
                            }
                            .foregroundStyle(DS.Colors.textTertiary)
                        }
                        .buttonStyle(.plainPointer)
                    }

                    Text(message.timestamp.formatted(.dateTime.hour().minute()))
                        .font(DS.Font.buttonSmall)
                        .foregroundStyle(DS.Colors.textTertiary)

                    if message.isStreaming {
                        ProgressView()
                            .controlSize(.mini)
                    }
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.bottom, DS.Spacing.sm)
            }
            .background(DS.Colors.fillSecondary, in: RoundedRectangle(cornerRadius: DS.Radius.xl))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.xl).strokeBorder(DS.Colors.border, lineWidth: 0.5))

            Spacer(minLength: 40)
        }
        .padding(.horizontal, DS.Spacing.xl)
        .padding(.vertical, DS.Spacing.sm)
    }

    private var errorBubble: some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            ZStack {
                Circle()
                    .fill(DS.Colors.danger.opacity(0.10))
                    .frame(width: 28, height: 28)
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: DS.IconSize.sm, weight: .semibold))
                    .foregroundStyle(DS.Colors.danger)
            }
            .padding(.top, 2)

            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text(message.content)
                    .font(DS.Font.body)
                    .foregroundStyle(DS.Colors.danger)

                if let onRetry {
                    Button(action: onRetry) {
                        HStack(spacing: DS.Spacing.xs) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: DS.IconSize.sm, weight: .semibold))
                            Text("Retry")
                                .font(DS.Font.caption)
                                .fontWeight(.semibold)
                        }
                        .foregroundStyle(DS.Colors.accent)
                        .padding(.horizontal, DS.Spacing.md)
                        .padding(.vertical, DS.Spacing.xs + 1)
                        .background(DS.Colors.accentFill, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                    }
                    .buttonStyle(.plainPointer)
                }
            }

            Spacer(minLength: 60)
        }
        .padding(.horizontal, DS.Spacing.xl)
        .padding(.vertical, DS.Spacing.sm)
    }
}
