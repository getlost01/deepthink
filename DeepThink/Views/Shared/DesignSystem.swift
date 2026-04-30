import SwiftUI

// MARK: - Design Tokens

enum DS {
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 28
        static let xxxl: CGFloat = 36
    }

    enum Radius {
        static let sm: CGFloat = 6
        static let md: CGFloat = 10
        static let lg: CGFloat = 14
        static let xl: CGFloat = 18
    }

    enum Font {
        static let hero: SwiftUI.Font = .system(size: 28, weight: .bold, design: .default)
        static let title: SwiftUI.Font = .system(size: 20, weight: .semibold)
        static let heading: SwiftUI.Font = .system(size: 15, weight: .semibold)
        static let body: SwiftUI.Font = .system(size: 13)
        static let caption: SwiftUI.Font = .system(size: 11)
        static let tiny: SwiftUI.Font = .system(size: 10)
        static let mono: SwiftUI.Font = .system(size: 12, weight: .regular, design: .monospaced)
        static let monoSmall: SwiftUI.Font = .system(size: 10, weight: .regular, design: .monospaced)
    }

    enum Colors {
        static let accent = Color.purple
        static let surface = Color(nsColor: .controlBackgroundColor)
        static let surfaceElevated = Color(nsColor: .windowBackgroundColor)
        static let border = Color.primary.opacity(0.08)
        static let borderSubtle = Color.primary.opacity(0.04)
        static let textPrimary = Color.primary
        static let textSecondary = Color.secondary
        static let textTertiary = Color.primary.opacity(0.3)
    }
}

// MARK: - Card

struct DSCard<Content: View>: View {
    var padding: CGFloat = DS.Spacing.lg
    var material: Bool = false
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .background {
                if material {
                    RoundedRectangle(cornerRadius: DS.Radius.lg)
                        .fill(.ultraThinMaterial)
                } else {
                    RoundedRectangle(cornerRadius: DS.Radius.lg)
                        .fill(.background)
                        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .strokeBorder(DS.Colors.border, lineWidth: 0.5)
            }
    }
}

// MARK: - Glass Card

struct DSGlassCard<Content: View>: View {
    var padding: CGFloat = DS.Spacing.lg
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.lg))
            .overlay {
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
            }
    }
}

// MARK: - Section Header

struct DSSectionHeader: View {
    let title: String
    var count: Int? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            Text(title)
                .font(DS.Font.heading)
                .foregroundStyle(DS.Colors.textPrimary)

            if let count {
                Text("\(count)")
                    .font(DS.Font.tiny)
                    .fontWeight(.medium)
                    .foregroundStyle(DS.Colors.textSecondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(DS.Colors.border, in: Capsule())
            }

            Spacer()

            if let action {
                Button("View All", action: action)
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Colors.accent)
                    .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Icon Badge

struct DSIconBadge: View {
    let icon: String
    var color: Color = DS.Colors.accent
    var size: CGFloat = 32

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: size * 0.45, weight: .medium))
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: size * 0.25))
    }
}

// MARK: - Pill Badge

struct DSPill: View {
    let text: String
    var color: Color = DS.Colors.accent

    var body: some View {
        Text(text)
            .font(DS.Font.tiny)
            .fontWeight(.medium)
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.1), in: Capsule())
    }
}

// MARK: - Search Field

struct DSSearchField: View {
    @Binding var text: String
    var placeholder: String = "Search..."
    var icon: String = "magnifyingglass"
    var onSubmit: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .foregroundStyle(DS.Colors.textTertiary)
                .font(.system(size: 14))

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(DS.Font.body)
                .onSubmit { onSubmit?() }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
        .overlay {
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .strokeBorder(DS.Colors.border, lineWidth: 0.5)
        }
    }
}

// MARK: - Action Button

struct DSActionButton: View {
    let title: String
    let icon: String
    var color: Color = DS.Colors.accent
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                Text(title)
                    .font(DS.Font.caption)
                    .fontWeight(.medium)
            }
            .foregroundStyle(color)
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: DS.Radius.sm))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Empty State

struct DSEmptyState: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    var action: (() -> Void)? = nil
    var actionTitle: String = "Get Started"

    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundStyle(DS.Colors.textTertiary)

            VStack(spacing: DS.Spacing.xs) {
                Text(title)
                    .font(DS.Font.heading)
                    .foregroundStyle(DS.Colors.textSecondary)
                if let subtitle {
                    Text(subtitle)
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Colors.textTertiary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 320)
                }
            }

            if let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .tint(DS.Colors.accent)
                    .controlSize(.regular)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Row

struct DSRow<Leading: View, Trailing: View>: View {
    @ViewBuilder let leading: () -> Leading
    let title: String
    var subtitle: String? = nil
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            leading()

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DS.Font.body)
                    .lineLimit(1)
                if let subtitle {
                    Text(subtitle)
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Colors.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            trailing()
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
    }
}

// MARK: - Toolbar Style

struct DSToolbar<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: DS.Spacing.md) {
                content()
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.vertical, DS.Spacing.md)
            .background(.bar)

            Divider()
        }
    }
}

// MARK: - View Extensions

extension View {
    func dsCard(padding: CGFloat = DS.Spacing.lg) -> some View {
        self
            .padding(padding)
            .background(.background, in: RoundedRectangle(cornerRadius: DS.Radius.lg))
            .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
            .overlay {
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .strokeBorder(DS.Colors.border, lineWidth: 0.5)
            }
    }

    func dsGlass(padding: CGFloat = DS.Spacing.lg) -> some View {
        self
            .padding(padding)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.lg))
            .overlay {
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
            }
    }

    func dsPage() -> some View {
        self
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color(nsColor: .windowBackgroundColor))
    }
}
