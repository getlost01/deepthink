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
                        .font(.system(size: 13))
                        .padding(.horizontal, DS.Spacing.lg)
                        .padding(.vertical, DS.Spacing.md)
                        .background(DS.Colors.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(DS.Colors.accent.opacity(0.25), lineWidth: 1))

                    HStack(spacing: DS.Spacing.sm) {
                        Button {
                            isEditing = false
                        } label: {
                            Text("Cancel")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(DS.Colors.textTertiary)
                        }
                        .buttonStyle(.plainPointer)

                        Button {
                            isEditing = false
                            onEdit?(editText)
                        } label: {
                            Text("Send")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.white)
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
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(DS.Colors.textTertiary)
                                .frame(width: 24, height: 24)
                                .background(DS.Colors.fill, in: Circle())
                        }
                        .buttonStyle(.plainPointer)
                        .help("Edit message")
                        .transition(.opacity)
                    }

                    Text(message.content)
                        .font(.system(size: 13))
                        .foregroundStyle(DS.Colors.textPrimary)
                        .textSelection(.enabled)
                        .padding(.horizontal, DS.Spacing.lg)
                        .padding(.vertical, DS.Spacing.md)
                        .frame(maxWidth: 560, alignment: .trailing)
                        .background(DS.Colors.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(DS.Colors.accent.opacity(0.12), lineWidth: 1))
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
                    .frame(width: 24, height: 24)
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .semibold))
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
                                .font(.system(size: 9, weight: .medium))
                            Text(copied ? "Copied" : "Copy")
                                .font(.system(size: 10, weight: .medium))
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
                                    .font(.system(size: 9, weight: .medium))
                                Text("Save as Note")
                                    .font(.system(size: 10, weight: .medium))
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
                                    .font(.system(size: 9, weight: .medium))
                                Text("Create Task")
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundStyle(DS.Colors.textTertiary)
                        }
                        .buttonStyle(.plainPointer)
                    }

                    Text(message.timestamp.formatted(.dateTime.hour().minute()))
                        .font(.system(size: 10))
                        .foregroundStyle(DS.Colors.textTertiary)

                    if message.isStreaming {
                        ProgressView()
                            .controlSize(.mini)
                    }
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.bottom, DS.Spacing.sm)
            }
            .background(DS.Colors.fillSecondary, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(DS.Colors.border, lineWidth: 0.5))

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
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DS.Colors.danger)
            }
            .padding(.top, 2)

            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text(message.content)
                    .font(.system(size: 13))
                    .foregroundStyle(DS.Colors.danger.opacity(0.9))

                if let onRetry {
                    Button(action: onRetry) {
                        HStack(spacing: DS.Spacing.xs) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 10, weight: .semibold))
                            Text("Retry")
                                .font(.system(size: 11, weight: .semibold))
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
