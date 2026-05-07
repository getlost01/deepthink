import SwiftUI

struct ChatBubble: View {
    let message: AIMessage
    var onRetry: (() -> Void)?
    var onEdit: ((String) -> Void)?
    var onSaveResponse: ((String) -> Void)?
    var branchInfo: (current: Int, total: Int)?
    var onSwitchBranch: ((Int) -> Void)?
    @State private var copied = false
    @State private var isEditing = false
    @State private var editText = ""
    @State private var showTokenDetail = false

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
        HStack(alignment: .top, spacing: DS.Spacing.sm) {
            Spacer(minLength: 80)

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
                VStack(alignment: .trailing, spacing: 0) {
                    HStack(spacing: DS.Spacing.xs) {
                        Text(message.timestamp.formatted(.dateTime.hour().minute()))
                            .font(DS.Font.micro)
                            .foregroundStyle(DS.Colors.textTertiary)
                        Text("You")
                            .font(DS.Font.micro)
                            .fontWeight(.medium)
                            .foregroundStyle(DS.Colors.textTertiary)

                        if onEdit != nil {
                            ChatEditButton {
                                editText = message.content
                                isEditing = true
                            }
                        }
                    }
                    .padding(.trailing, DS.Spacing.sm)
                    .padding(.bottom, DS.Spacing.xxs)

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

            ZStack {
                Circle()
                    .fill(DS.Colors.accent.opacity(0.12))
                    .frame(width: 28, height: 28)
                Text("Y")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(DS.Colors.accent)
            }
            .padding(.top, DS.Spacing.lg)
        }
        .padding(.horizontal, DS.Spacing.xl)
        .padding(.vertical, DS.Spacing.sm)
        .overlay(alignment: .bottomTrailing) {
            if let info = branchInfo, info.total > 1 {
                HStack(spacing: DS.Spacing.xs) {
                    Button {
                        onSwitchBranch?(info.current - 1)
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: DS.IconSize.xs, weight: .bold))
                            .foregroundStyle(info.current > 0 ? DS.Colors.textSecondary : DS.Colors.textTertiary.opacity(0.4))
                    }
                    .buttonStyle(.plainPointer)
                    .disabled(info.current <= 0)

                    Text("\(info.current + 1)/\(info.total)")
                        .font(.system(size: DS.IconSize.xs, weight: .medium, design: .rounded))
                        .foregroundStyle(DS.Colors.textTertiary)

                    Button {
                        onSwitchBranch?(info.current + 1)
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: DS.IconSize.xs, weight: .bold))
                            .foregroundStyle(info.current < info.total - 1 ? DS.Colors.textSecondary : DS.Colors.textTertiary.opacity(0.4))
                    }
                    .buttonStyle(.plainPointer)
                    .disabled(info.current >= info.total - 1)
                }
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.vertical, 3)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(DS.Colors.border, lineWidth: 0.5))
                .offset(y: DS.Spacing.md)
                .padding(.trailing, DS.Spacing.xl)
            }
        }
    }

    private var assistantBubble: some View {
        HStack(alignment: .top, spacing: DS.Spacing.sm) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 28, height: 28)
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .padding(.top, DS.Spacing.sm)

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: DS.Spacing.xs) {
                    if message.isStreaming {
                        StreamingAsterisk()
                        Text("DeepThinking...")
                            .font(DS.Font.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(DS.Colors.accent)
                        StreamingTimer(startTime: message.timestamp)
                    } else {
                        Text("DeepThink")
                            .font(DS.Font.micro)
                            .fontWeight(.medium)
                            .foregroundStyle(DS.Colors.textTertiary)
                    }
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.top, DS.Spacing.sm)
                .padding(.bottom, DS.Spacing.xxs)

                ChatContentView(content: message.content)
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.bottom, DS.Spacing.sm)

                if !message.isStreaming {
                    Divider()
                        .padding(.horizontal, DS.Spacing.sm)

                    HStack(spacing: DS.Spacing.xs) {
                        assistantActionButton(
                            icon: copied ? "checkmark" : "doc.on.doc",
                            label: copied ? "Copied" : "Copy",
                            color: copied ? DS.Colors.success : DS.Colors.textTertiary
                        ) {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(message.content, forType: .string)
                            copied = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                        }

                        if let onSaveResponse {
                            assistantActionButton(icon: "square.and.arrow.down", label: "Save Response", color: DS.Colors.textTertiary) {
                                onSaveResponse(message.content)
                            }
                        }

                        Spacer()

                        if let usage = message.tokenUsage {
                            Button {
                                showTokenDetail.toggle()
                            } label: {
                                HStack(spacing: 3) {
                                    Image(systemName: "number")
                                        .font(.system(size: DS.IconSize.xs, weight: .semibold))
                                    Text(usage.formattedTokens)
                                        .font(DS.Font.micro)
                                }
                                .foregroundStyle(DS.Colors.textTertiary)
                                .padding(.horizontal, DS.Spacing.sm)
                                .padding(.vertical, DS.Spacing.xs)
                                .background(DS.Colors.fill, in: Capsule())
                            }
                            .buttonStyle(.plainPointer)
                            .popover(isPresented: $showTokenDetail, arrowEdge: .top) {
                                TokenDetailPopover(usage: usage)
                            }
                        }

                        Text(message.timestamp.formatted(.dateTime.hour().minute()))
                            .font(DS.Font.micro)
                            .foregroundStyle(DS.Colors.textTertiary)
                    }
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, DS.Spacing.xs + 1)
                }
            }
            .background(DS.Colors.fillSecondary, in: RoundedRectangle(cornerRadius: DS.Radius.xl))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.xl).strokeBorder(DS.Colors.border, lineWidth: 0.5))

            Spacer(minLength: 40)
        }
        .padding(.horizontal, DS.Spacing.xl)
        .padding(.vertical, DS.Spacing.sm)
    }

    private func assistantActionButton(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        ChatActionButton(icon: icon, label: label, color: color, action: action)
    }

    // MARK: - Error classification

    private enum ChatErrorKind {
        case rateLimited
        case noCredits
        case other

        init(_ text: String) {
            let l = text.lowercased()
            if l.contains("rate limit") || l.contains("too many requests") || l.contains("overloaded") {
                self = .rateLimited
            } else if l.contains("credit") || l.contains("billing") || l.contains("insufficient") || l.contains("payment") {
                self = .noCredits
            } else {
                self = .other
            }
        }
    }

    private var errorBubble: some View {
        let kind = ChatErrorKind(message.content)

        return HStack(alignment: .top, spacing: DS.Spacing.md) {
            ZStack {
                Circle()
                    .fill(errorBubbleIconBg(kind))
                    .frame(width: 32, height: 32)
                Image(systemName: errorBubbleIcon(kind))
                    .font(.system(size: DS.IconSize.sm, weight: .semibold))
                    .foregroundStyle(errorBubbleColor(kind))
            }
            .padding(.top, 2)

            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text(errorBubbleTitle(kind))
                    .font(DS.Font.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(errorBubbleColor(kind))

                Text(errorBubbleBody(kind, raw: message.content))
                    .font(DS.Font.body)
                    .foregroundStyle(DS.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: DS.Spacing.sm) {
                    if let onRetry {
                        Button(action: onRetry) {
                            HStack(spacing: DS.Spacing.xs) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: DS.IconSize.xs, weight: .semibold))
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

                    if kind == .noCredits {
                        Button {
                            NSWorkspace.shared.open(URL(string: "https://console.anthropic.com/settings/billing")!)
                        } label: {
                            HStack(spacing: DS.Spacing.xs) {
                                Image(systemName: "creditcard")
                                    .font(.system(size: DS.IconSize.xs, weight: .medium))
                                Text("Add Credits")
                                    .font(DS.Font.caption)
                                    .fontWeight(.semibold)
                            }
                            .foregroundStyle(DS.Colors.onAccent)
                            .padding(.horizontal, DS.Spacing.md)
                            .padding(.vertical, DS.Spacing.xs + 1)
                            .background(DS.Colors.accent, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                        }
                        .buttonStyle(.plainPointer)
                    }

                    if kind == .rateLimited {
                        Button {
                            NSWorkspace.shared.open(URL(string: "https://console.anthropic.com/settings/limits")!)
                        } label: {
                            HStack(spacing: DS.Spacing.xs) {
                                Image(systemName: "gauge.with.needle")
                                    .font(.system(size: DS.IconSize.xs, weight: .medium))
                                Text("View Limits")
                                    .font(DS.Font.caption)
                            }
                            .foregroundStyle(DS.Colors.textSecondary)
                            .padding(.horizontal, DS.Spacing.md)
                            .padding(.vertical, DS.Spacing.xs + 1)
                            .background(DS.Colors.fill, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                            .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm).strokeBorder(DS.Colors.border, lineWidth: 1))
                        }
                        .buttonStyle(.plainPointer)
                    }
                }
            }

            Spacer(minLength: 60)
        }
        .padding(.horizontal, DS.Spacing.xl)
        .padding(.vertical, DS.Spacing.sm)
    }

    private func errorBubbleColor(_ kind: ChatErrorKind) -> Color {
        switch kind {
        case .rateLimited: DS.Colors.warning
        case .noCredits: DS.Colors.danger
        case .other: DS.Colors.danger
        }
    }

    private func errorBubbleIconBg(_ kind: ChatErrorKind) -> Color {
        errorBubbleColor(kind).opacity(0.12)
    }

    private func errorBubbleIcon(_ kind: ChatErrorKind) -> String {
        switch kind {
        case .rateLimited: "timer"
        case .noCredits: "creditcard.trianglebadge.exclamationmark"
        case .other: "exclamationmark.triangle"
        }
    }

    private func errorBubbleTitle(_ kind: ChatErrorKind) -> String {
        switch kind {
        case .rateLimited: "Rate Limit Reached"
        case .noCredits: "Insufficient Credits"
        case .other: "Something went wrong"
        }
    }

    private func errorBubbleBody(_ kind: ChatErrorKind, raw: String) -> String {
        switch kind {
        case .rateLimited:
            "You've hit the Claude API rate limit. Please wait a moment and try again. If this happens often, consider upgrading your plan at console.anthropic.com."
        case .noCredits:
            "Your Claude API account has run out of credits. Add credits to your account at console.anthropic.com to continue using AI features."
        case .other:
            raw
        }
    }
}

// MARK: - Token Detail Popover

struct TokenDetailPopover: View {
    let usage: TokenUsage

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: DS.IconSize.xs, weight: .semibold))
                    .foregroundStyle(DS.Colors.accent)
                Text("Token Usage")
                    .font(DS.Font.caption)
                    .fontWeight(.semibold)
            }

            Divider()

            VStack(spacing: DS.Spacing.xs) {
                tokenRow("Input", value: usage.inputTokens, icon: "arrow.up.right", color: DS.Colors.accent)
                tokenRow("Output", value: usage.outputTokens, icon: "arrow.down.left", color: DS.Colors.success)
                if usage.cacheReadTokens > 0 {
                    tokenRow("Cache Read", value: usage.cacheReadTokens, icon: "arrow.triangle.2.circlepath", color: DS.Colors.info)
                }
                if usage.cacheCreationTokens > 0 {
                    tokenRow("Cache Write", value: usage.cacheCreationTokens, icon: "square.and.arrow.down", color: DS.Colors.warning)
                }
            }

            Divider()

            HStack {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "dollarsign.circle")
                        .font(.system(size: DS.IconSize.xs))
                        .foregroundStyle(DS.Colors.textTertiary)
                    Text(usage.formattedCost)
                        .font(DS.Font.small)
                        .fontWeight(.medium)
                }

                Spacer()

                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "clock")
                        .font(.system(size: DS.IconSize.xs))
                        .foregroundStyle(DS.Colors.textTertiary)
                    Text(usage.formattedDuration)
                        .font(DS.Font.small)
                        .fontWeight(.medium)
                }
            }
            .foregroundStyle(DS.Colors.textSecondary)
        }
        .padding(DS.Spacing.md)
        .frame(width: 200)
    }

    private func tokenRow(_ label: String, value: Int, icon: String, color: Color) -> some View {
        HStack {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: DS.IconSize.xs, weight: .medium))
                    .foregroundStyle(color)
                Text(label)
                    .font(DS.Font.small)
                    .foregroundStyle(DS.Colors.textSecondary)
            }
            Spacer()
            Text(formatTokenCount(value))
                .font(DS.Font.small)
                .fontWeight(.medium)
                .foregroundStyle(DS.Colors.textPrimary)
        }
    }

    private func formatTokenCount(_ count: Int) -> String {
        if count >= 1_000_000 { return String(format: "%.1fM", Double(count) / 1_000_000) }
        if count >= 1000 { return String(format: "%.1fK", Double(count) / 1000) }
        return "\(count)"
    }
}
