import SwiftUI

// MARK: - Design Tokens

enum DS {
    enum Spacing {
        static let xxxs: CGFloat = 1
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let xs3: CGFloat = 3
        static let xs4: CGFloat = 5
        static let xs2: CGFloat = 6
        static let sm: CGFloat = 8
        static let sm2: CGFloat = 10
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    enum Radius {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 6
        static let md: CGFloat = 8
        static let lg: CGFloat = 12
        static let xl: CGFloat = 14
        static let pill: CGFloat = 20
    }

    enum IconSize {
        static let micro: CGFloat = 7
        static let nano: CGFloat = 8
        static let xs: CGFloat = 9
        static let sm2: CGFloat = 10
        static let sm: CGFloat = 12
        static let md: CGFloat = 14
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let xxxl: CGFloat = 28
        static let hero: CGFloat = 40
    }

    enum Font {
        static let hero: SwiftUI.Font = .system(size: 48, weight: .light)
        static let display: SwiftUI.Font = .system(size: 24, weight: .bold)
        static let titleLarge: SwiftUI.Font = .system(size: 20, weight: .semibold)
        static let title: SwiftUI.Font = .system(size: 18, weight: .semibold)
        static let heading: SwiftUI.Font = .system(size: 14, weight: .semibold)
        static let body: SwiftUI.Font = .system(size: 13)
        static let caption: SwiftUI.Font = .system(size: 11)
        static let small: SwiftUI.Font = .system(size: 10, weight: .medium)
        static let micro: SwiftUI.Font = .system(size: 9, weight: .medium)
        static let buttonSmall: SwiftUI.Font = .system(size: 10, weight: .medium)
        static let mono: SwiftUI.Font = .system(size: 13, weight: .regular, design: .monospaced)
        static let monoSmall: SwiftUI.Font = .system(size: 11, weight: .regular, design: .monospaced)
        static let badge: SwiftUI.Font = .system(size: 7, weight: .bold)
        static let bodySmall: SwiftUI.Font = .system(size: 12)
        static let titleSmall: SwiftUI.Font = .system(size: 17, weight: .semibold)
        static let emptyStateIcon: SwiftUI.Font = .system(size: 32, weight: .light)
    }

    enum Colors {
        private static var p: DSThemePalette {
            DSThemeManager.shared.palette
        }

        static var accent: Color {
            p.accent
        }

        static var accentFill: Color {
            p.accentFill
        }

        static var accentGradient: LinearGradient {
            p.accentGradient
        }

        static var onAccent: Color {
            p.onAccent
        }

        static var page: Color {
            p.page
        }

        static var surface: Color {
            p.surface
        }

        static var surfaceElevated: Color {
            p.surfaceElevated
        }

        static var modal: Color {
            p.modal
        }

        static var card: Color {
            p.card
        }

        static var fill: Color {
            p.fill
        }

        static var fillSecondary: Color {
            p.fillSecondary
        }

        static var border: Color {
            p.border
        }

        static var borderHover: Color {
            p.borderHover
        }

        static var borderFocused: Color {
            p.borderFocused
        }

        static var textPrimary: Color {
            p.textPrimary
        }

        static var textSecondary: Color {
            p.textSecondary
        }

        static var textTertiary: Color {
            p.textTertiary
        }

        static var scrollMaskOpaque: Color {
            p.scrollMaskOpaque
        }

        static var scrollMaskFade: Color {
            p.scrollMaskFade
        }

        static var gridDot: Color {
            p.gridDot
        }

        static var success: Color {
            p.success
        }

        static var warning: Color {
            p.warning
        }

        static var warningFill: Color {
            p.warningFill
        }

        static var danger: Color {
            p.danger
        }

        static var knowledge: Color {
            p.knowledge
        }

        static var info: Color {
            p.info
        }

        static var teal: Color {
            p.teal
        }

        static var purple: Color {
            p.purple
        }

        static var amber: Color {
            p.amber
        }

        static var lime: Color {
            p.lime
        }

        static var slate: Color {
            p.slate
        }

        static var gold: Color {
            p.gold
        }

        static var sunrise: Color {
            p.sunrise
        }

        static var terminal: Color {
            p.terminal
        }

        static var terminalNS: NSColor {
            p.terminalNS
        }

        static var cardShadow: Color {
            p.cardShadow
        }

        static var modalShadow: Color {
            p.modalShadow
        }

        static var subtleShadow: Color {
            p.subtleShadow
        }

        static var overlayBg: Color {
            p.overlayBg
        }

        static var transparent: Color {
            DS.Colors.transparent
        }

        static func badgeFill(_ color: Color) -> Color {
            color.opacity(DS.Opacity.chipBackground)
        }

        static func badgeBorder(_ color: Color) -> Color {
            color.opacity(DS.Opacity.chipBorder)
        }

        static func iconBadgeFill(_ color: Color) -> Color {
            badgeFill(color)
        }

        static let projectColorHexes = [
            "#3D6FE8", "#E5484D", "#E88C1A", "#30A46C",
            "#6E56CF", "#9B5DE5", "#E54D8A", "#9A8B7A"
        ]
        static let projectColorNames: [String: String] = [
            "#3D6FE8": "Blue", "#007AFF": "Blue",
            "#E5484D": "Red", "#FF3B30": "Red",
            "#E88C1A": "Orange", "#FF9500": "Orange",
            "#30A46C": "Green", "#34C759": "Green",
            "#6E56CF": "Indigo", "#5856D6": "Indigo",
            "#9B5DE5": "Purple", "#AF52DE": "Purple",
            "#E54D8A": "Pink", "#FF2D55": "Pink",
            "#9A8B7A": "Brown", "#A2845E": "Brown"
        ]
    }

    enum Opacity {
        static let hover: Double = 0.06
        static let subtle: Double = 0.10
        static let chipBackground: Double = 0.10
        static let chipBorder: Double = 0.22
        static let disabled: Double = 0.5
        static let overlayBg: Double = 0.28
        static let decorative: Double = 0.04
        static let muted: Double = 0.6
        static let faint: Double = 0.4
        static let accentBorder: Double = 0.25
        static let accentSelection: Double = 0.15
        static let accentHighlight: Double = 0.3
        static let onAccentMuted: Double = 0.6
        static let onAccentSoft: Double = 0.7
        static let onAccentFaint: Double = 0.5
        static let warningFill: Double = 0.12
        static let warningBorder: Double = 0.25
        static let dangerFill: Double = 0.10
        static let dangerBorder: Double = 0.25
        static let successFill: Double = 0.12
        static let accentFillStrong: Double = 0.24
    }

    enum Layout {
        static let sidebarWidth: CGFloat = 200
        static let sidebarCollapsedWidth: CGFloat = 52
        static let panelWidth: CGFloat = 300
        static let toolbarHeight: CGFloat = 44
        static let rowHeight: CGFloat = 36
        static let commandPaletteTopInset: CGFloat = 80
        static let searchFieldHeight: CGFloat = 28
        static let iconButtonSize: CGFloat = 28
        static let sidebarIconSlot: CGFloat = 22
        static let welcomeDividerInset: CGFloat = 52
        static let settingsDividerInset: CGFloat = 28
        static let recentDividerInset: CGFloat = 40
        static let nestedListDividerInset: CGFloat = 20
        static let emptyStateVerticalPadding: CGFloat = 40
    }

    enum Animation {
        static let quick: SwiftUI.Animation = .easeInOut(duration: 0.15)
        static let standard: SwiftUI.Animation = .easeInOut(duration: 0.2)
    }
}

// MARK: - Page Header

struct DSPageHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            Text(title)
                .font(DS.Font.heading)
                .foregroundStyle(DS.Colors.textPrimary)

            Spacer()

            trailing()
        }
        .frame(height: DS.Layout.toolbarHeight)
        .padding(.horizontal, DS.Spacing.lg)
        .background(DS.Colors.page)
    }
}

extension DSPageHeader where Trailing == EmptyView {
    init(title: String) {
        self.title = title
        trailing = { EmptyView() }
    }
}

// MARK: - Stat Card

struct DSStatCard: View {
    let icon: String
    let label: String
    let value: String
    var color: Color = DS.Colors.accent
    var action: (() -> Void)?

    var body: some View {
        let card = VStack(spacing: DS.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: DS.IconSize.lg, weight: .medium))
                .foregroundStyle(color)
                .frame(width: DS.Layout.iconButtonSize, height: DS.Layout.iconButtonSize)
                .background(DS.Colors.badgeFill(color), in: RoundedRectangle(cornerRadius: DS.Radius.sm))

            Text(value)
                .font(DS.Font.title)
                .fontWeight(.bold)
                .foregroundStyle(DS.Colors.textPrimary)

            Text(label)
                .font(DS.Font.caption)
                .foregroundStyle(DS.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(DS.Spacing.lg)
        .background(DS.Colors.card, in: RoundedRectangle(cornerRadius: DS.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .strokeBorder(DS.Colors.border, lineWidth: 1)
        )

        if let action {
            Button(action: action) { card }
                .buttonStyle(.plainPointer)
        } else {
            card
        }
    }
}

// MARK: - Card

struct DSCard<Content: View>: View {
    var padding: CGFloat = DS.Spacing.lg
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .background(DS.Colors.card, in: RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .strokeBorder(DS.Colors.border, lineWidth: 1)
            )
    }
}

// MARK: - Section Header

struct DSSectionHeader: View {
    let title: String
    var count: Int?
    var action: (() -> Void)?

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            Text(title)
                .font(DS.Font.heading)
                .foregroundStyle(DS.Colors.textPrimary)

            if let count {
                Text("\(count)")
                    .font(DS.Font.small)
                    .foregroundStyle(DS.Colors.textTertiary)
                    .padding(.horizontal, DS.Spacing.xs + 2)
                    .padding(.vertical, DS.Spacing.xxs)
                    .background(DS.Colors.fill, in: Capsule())
            }

            Spacer()

            if let action {
                Button("View All", action: action)
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Colors.textSecondary)
                    .buttonStyle(.plainPointer)
            }
        }
    }
}

// MARK: - Toolbar Bar

struct DSToolbarBar<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            content()
        }
        .frame(height: DS.Layout.toolbarHeight, alignment: .leading)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DS.Spacing.md)
        .background(DS.Colors.page)
    }
}

// MARK: - Tab Button

struct DSTabButton: View {
    let title: String
    var icon: String?
    let isSelected: Bool
    var count: Int?
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                HStack(spacing: DS.Spacing.xs) {
                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: DS.IconSize.sm, weight: .medium))
                    }
                    Text(title)
                        .font(DS.Font.caption)
                        .fontWeight(isSelected ? .semibold : .regular)
                    if let count, count > 0 {
                        Text("\(count)")
                            .font(DS.Font.micro)
                            .fontWeight(.semibold)
                            .foregroundStyle(isSelected ? DS.Colors.onAccent : DS.Colors.textTertiary)
                            .padding(.horizontal, DS.Spacing.xs)
                            .padding(.vertical, 1)
                            .background(isSelected ? DS.Colors.accent : DS.Colors.fillSecondary, in: Capsule())
                    }
                }
                .foregroundStyle(isSelected ? DS.Colors.textPrimary : (isHovered ? DS.Colors.textPrimary : DS.Colors.textSecondary))
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.sm)
                .background(isHovered && !isSelected ? DS.Colors.fillSecondary : DS.Colors.transparent, in: RoundedRectangle(cornerRadius: DS.Radius.sm))

                Rectangle()
                    .fill(isSelected ? DS.Colors.accent : DS.Colors.transparent)
                    .frame(height: 2)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plainPointer)
        .onHover { isHovered = $0 }
        .animation(DS.Animation.quick, value: isHovered)
    }
}

// MARK: - Icon Badge

struct DSIconBadge: View {
    let icon: String
    var color: Color = DS.Colors.textSecondary
    var background: Color = DS.Colors.fill
    var size: CGFloat = 28

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: size * 0.45, weight: .medium))
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .background(background, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm).strokeBorder(DS.Colors.border, lineWidth: 1))
    }
}

// MARK: - Pill Badge

struct DSPill: View {
    let text: String
    var color: Color = DS.Colors.textSecondary

    var body: some View {
        Text(text)
            .font(DS.Font.small)
            .foregroundStyle(color)
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, DS.Spacing.xs3)
            .background(DS.Colors.badgeFill(color), in: Capsule())
    }
}

// MARK: - Search Field

struct DSSearchField: View {
    @Binding var text: String
    var placeholder: String = "Search..."
    var icon: String = "magnifyingglass"
    var onSubmit: (() -> Void)?

    var body: some View {
        DSThemedSearchFieldContent(text: $text, placeholder: placeholder, icon: icon, onSubmit: onSubmit)
    }
}

private struct DSThemedSearchFieldContent: View {
    @Environment(\.dsPalette) private var palette
    @Bindable private var theme = DSThemeManager.shared
    @Binding var text: String
    let placeholder: String
    let icon: String
    let onSubmit: (() -> Void)?

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .foregroundStyle(palette.textTertiary)
                .font(.system(size: DS.IconSize.md))

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(DS.Font.body)
                .foregroundStyle(palette.textPrimary)
                .tint(palette.accent)
                .onSubmit { onSubmit?() }
                .id(theme.themeRevision)
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.sm + 2)
        .background(palette.fillSecondary, in: RoundedRectangle(cornerRadius: DS.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .strokeBorder(palette.border, lineWidth: 1)
        )
    }
}

// MARK: - Action Button

struct DSActionButton: View {
    let title: String
    let icon: String
    var color: Color = DS.Colors.textPrimary
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: DS.IconSize.sm, weight: .medium))
                Text(title)
                    .font(DS.Font.caption)
                    .fontWeight(.medium)
            }
            .foregroundStyle(color)
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .background(isHovered ? DS.Colors.fillSecondary : DS.Colors.fill, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.sm)
                    .strokeBorder(DS.Colors.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plainPointer)
        .onHover { isHovered = $0 }
        .animation(DS.Animation.quick, value: isHovered)
    }
}

// MARK: - Empty State

struct DSEmptyState: View {
    let icon: String
    let title: String
    var subtitle: String?
    var hint: String?
    var action: (() -> Void)?
    var actionTitle: String = "Get Started"

    var body: some View {
        VStack(spacing: DS.Spacing.xl) {
            Image(systemName: icon)
                .font(DS.Font.emptyStateIcon)
                .foregroundStyle(DS.Colors.textTertiary)

            VStack(spacing: DS.Spacing.sm) {
                Text(title)
                    .font(DS.Font.heading)
                    .foregroundStyle(DS.Colors.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(DS.Font.body)
                        .foregroundStyle(DS.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 340)
                }
            }

            if let action {
                Button(action: action) {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "plus")
                            .font(.system(size: DS.IconSize.sm, weight: .medium))
                        Text(actionTitle)
                            .font(DS.Font.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(DS.Colors.onAccent)
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.sm)
                    .background(DS.Colors.accent, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                }
                .buttonStyle(.plainPointer)
            }

            if let hint {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "lightbulb")
                        .font(.system(size: DS.IconSize.xs, weight: .medium))
                    Text(hint)
                        .font(DS.Font.caption)
                }
                .foregroundStyle(DS.Colors.textTertiary)
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.sm)
                .background(DS.Colors.fill, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
            }
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Help Popover Button

struct DSHelpButton: View {
    let text: String
    @State private var showHelp = false

    var body: some View {
        Button {
            showHelp.toggle()
        } label: {
            Image(systemName: "questionmark.circle")
                .font(.system(size: DS.IconSize.md, weight: .medium))
                .foregroundStyle(DS.Colors.textTertiary)
        }
        .buttonStyle(.plainPointer)
        .popover(isPresented: $showHelp, arrowEdge: .bottom) {
            Text(text)
                .font(DS.Font.body)
                .foregroundStyle(DS.Colors.textSecondary)
                .padding(DS.Spacing.lg)
                .frame(maxWidth: 320)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Row

struct DSRow<Leading: View, Trailing: View>: View {
    @ViewBuilder let leading: () -> Leading
    let title: String
    var subtitle: String?
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            leading()

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
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

// MARK: - Toolbar Icon Button

struct DSToolbarButton: View {
    let icon: String
    var color: Color = DS.Colors.textTertiary
    var size: CGFloat = DS.IconSize.md
    var label: String?
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size, weight: .medium))
                .foregroundStyle(isHovered ? DS.Colors.textPrimary : color)
                .frame(width: DS.Layout.iconButtonSize, height: DS.Layout.iconButtonSize)
                .background(isHovered ? DS.Colors.fillSecondary : DS.Colors.fill, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm).strokeBorder(DS.Colors.border, lineWidth: 1))
        }
        .buttonStyle(.plainPointer)
        .onHover { isHovered = $0 }
        .animation(DS.Animation.quick, value: isHovered)
        .accessibilityLabel(label ?? icon)
    }
}

// MARK: - Archive Button

struct DSArchiveButton: View {
    let isOn: Bool
    var count: Int = 0
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: isOn ? "archivebox.fill" : "archivebox")
                .font(.system(size: DS.IconSize.sm, weight: .medium))
                .foregroundStyle(isOn ? DS.Colors.accent : (isHovered ? DS.Colors.accent : DS.Colors.textSecondary))
                .frame(width: DS.Layout.iconButtonSize, height: DS.Layout.iconButtonSize)
                .background(
                    isOn ? DS.Colors.accentFill : (isHovered ? DS.Colors.fillSecondary : DS.Colors.fill),
                    in: RoundedRectangle(cornerRadius: DS.Radius.sm)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.sm)
                        .strokeBorder(
                            isOn ? DS.Colors.badgeBorder(DS.Colors.accent) : (isHovered ? DS.Colors.borderHover : DS.Colors.border),
                            lineWidth: 1
                        )
                )
                .overlay(alignment: .topTrailing) {
                    if count > 0 {
                        Text(count > 99 ? "99+" : "\(count)")
                            .font(DS.Font.badge)
                            .foregroundStyle(DS.Colors.onAccent)
                            .padding(.horizontal, DS.Spacing.xs3)
                            .frame(minWidth: 14, minHeight: 14)
                            .background(isOn ? DS.Colors.accent : DS.Colors.textSecondary, in: Capsule())
                            .offset(x: DS.Spacing.xs4, y: -DS.Spacing.xs4)
                    }
                }
        }
        .buttonStyle(.plainPointer)
        .onHover { isHovered = $0 }
        .animation(DS.Animation.quick, value: isHovered)
        .help(isOn ? "Hide Archived" : "Show Archived (\(count))")
    }
}

// MARK: - Add Button

struct DSAddButton: View {
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: DS.IconSize.sm, weight: .medium))
                .foregroundStyle(isHovered ? DS.Colors.accent : DS.Colors.textSecondary)
                .frame(width: DS.Layout.iconButtonSize, height: DS.Layout.iconButtonSize)
                .background(isHovered ? DS.Colors.fillSecondary : DS.Colors.fill, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.sm)
                        .strokeBorder(isHovered ? DS.Colors.borderHover : DS.Colors.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plainPointer)
        .onHover { isHovered = $0 }
        .animation(DS.Animation.quick, value: isHovered)
    }
}

// MARK: - Stat Chip

struct DSStatChip: View {
    let label: String
    let value: String
    let icon: String
    var color: Color = DS.Colors.textSecondary

    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: DS.IconSize.sm, weight: .medium))
            Text(value)
                .font(DS.Font.caption)
                .fontWeight(.medium)
        }
        .foregroundStyle(color)
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
        .background(DS.Colors.fill, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.sm)
                .strokeBorder(DS.Colors.border, lineWidth: 1)
        )
    }
}

// MARK: - Labeled Text Field

struct DSLabeledTextField: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""
    var axis: Axis = .horizontal

    var body: some View {
        DSLabeledTextFieldContent(label: label, text: $text, placeholder: placeholder, axis: axis)
    }
}

private struct DSLabeledTextFieldContent: View {
    @Environment(\.dsPalette) private var palette
    @Bindable private var theme = DSThemeManager.shared
    let label: String
    @Binding var text: String
    let placeholder: String
    let axis: Axis

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(label)
                .font(DS.Font.small)
                .foregroundStyle(palette.textTertiary)
                .textCase(.uppercase)

            TextField(placeholder.isEmpty ? label : placeholder, text: $text, axis: axis)
                .textFieldStyle(.plain)
                .font(DS.Font.body)
                .foregroundStyle(palette.textPrimary)
                .tint(palette.accent)
                .id(theme.themeRevision)
                .dsInputField()
        }
    }
}

struct DSLabeledTextEditor: View {
    let label: String
    @Binding var text: String
    var minHeight: CGFloat = 200

    var body: some View {
        DSLabeledTextEditorContent(label: label, text: $text, minHeight: minHeight)
    }
}

private struct DSLabeledTextEditorContent: View {
    @Environment(\.dsPalette) private var palette
    @Bindable private var theme = DSThemeManager.shared
    let label: String
    @Binding var text: String
    let minHeight: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(label)
                .font(DS.Font.small)
                .foregroundStyle(palette.textTertiary)
                .textCase(.uppercase)

            TextEditor(text: $text)
                .font(DS.Font.body)
                .foregroundStyle(palette.textPrimary)
                .tint(palette.accent)
                .scrollContentBackground(.hidden)
                .frame(minHeight: minHeight)
                .id(theme.themeRevision)
                .padding(DS.Spacing.md)
                .background(palette.fillSecondary, in: RoundedRectangle(cornerRadius: DS.Radius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.md)
                        .strokeBorder(palette.border, lineWidth: 1)
                )
        }
    }
}

struct DSLabeledPicker<SelectionValue: Hashable, Content: View>: View {
    let label: String
    @Binding var selection: SelectionValue
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(label)
                .font(DS.Font.small)
                .foregroundStyle(DS.Colors.textTertiary)
                .textCase(.uppercase)

            Picker("", selection: $selection) {
                content()
            }
            .pickerStyle(.menu)
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.xs)
            .background(DS.Colors.fillSecondary, in: RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .strokeBorder(DS.Colors.border, lineWidth: 1)
            )
        }
    }
}

// MARK: - Divider with label

struct DSSectionDivider: View {
    var label: String?

    var body: some View {
        if let label {
            HStack(spacing: DS.Spacing.md) {
                Rectangle()
                    .fill(DS.Colors.border)
                    .frame(height: 1)
                Text(label)
                    .font(DS.Font.small)
                    .foregroundStyle(DS.Colors.textTertiary)
                    .textCase(.uppercase)
                Rectangle()
                    .fill(DS.Colors.border)
                    .frame(height: 1)
            }
        } else {
            Divider()
        }
    }
}

// MARK: - Section Banner

struct DSSectionBanner: View {
    let icon: String
    let title: String
    let subtitle: String
    var color: Color = DS.Colors.accent
    var onDismiss: (() -> Void)?

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: DS.IconSize.md, weight: .medium))
                .foregroundStyle(color)
                .frame(width: DS.Layout.iconButtonSize, height: DS.Layout.iconButtonSize)
                .background(DS.Colors.badgeFill(color), in: RoundedRectangle(cornerRadius: DS.Radius.sm))

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                HStack(spacing: DS.Spacing.xs) {
                    Text(title)
                        .font(DS.Font.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(DS.Colors.textPrimary)
                    Text("(\(subtitle))")
                        .font(DS.Font.small)
                        .foregroundStyle(DS.Colors.textTertiary)
                        .lineLimit(1)
                }
            }

            if let onDismiss {
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: DS.IconSize.xs, weight: .semibold))
                        .foregroundStyle(DS.Colors.textTertiary)
                        .frame(width: 20, height: 20)
                        .background(DS.Colors.fillSecondary, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                }
                .buttonStyle(.plainPointer)
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.Colors.card)
    }
}

// MARK: - Warning Strip

struct DSWarningStrip: View {
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: DS.IconSize.xs))
                .foregroundStyle(DS.Colors.warning)
            Text(message)
                .font(DS.Font.small)
                .foregroundStyle(DS.Colors.textSecondary)
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(DS.Font.small)
                    .foregroundStyle(DS.Colors.warning)
                    .buttonStyle(.plainPointer)
            }
        }
        .padding(.horizontal, DS.Spacing.xl)
        .padding(.vertical, DS.Spacing.xs)
        .frame(maxWidth: .infinity)
        .background(DS.Colors.warningFill)
    }
}

// MARK: - Filter Chip

struct DSFilterChip: View {
    let label: String
    var count: Int?
    let isSelected: Bool
    var activeColor: Color = DS.Colors.accent
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.xs) {
                Text(label)
                    .font(DS.Font.small)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundStyle(isSelected ? activeColor : DS.Colors.textSecondary)
                if let count {
                    Text("\(count)")
                        .font(DS.Font.micro)
                        .fontWeight(.medium)
                        .foregroundStyle(isSelected ? activeColor : DS.Colors.textTertiary)
                        .padding(.horizontal, DS.Spacing.xs)
                        .padding(.vertical, DS.Spacing.xxs)
                        .background(
                            isSelected ? DS.Colors.badgeFill(activeColor) : DS.Colors.fillSecondary,
                            in: Capsule()
                        )
                }
            }
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xs)
            .background(
                isSelected ? DS.Colors.badgeFill(activeColor) : (isHovered ? DS.Colors.fill : DS.Colors.transparent),
                in: Capsule()
            )
            .overlay(
                Capsule().strokeBorder(
                    isSelected ? DS.Colors.badgeBorder(activeColor) : DS.Colors.border,
                    lineWidth: 1
                )
            )
        }
        .buttonStyle(.plainPointer)
        .onHover { isHovered = $0 }
        .animation(DS.Animation.quick, value: isHovered)
    }
}

// MARK: - Field Label

struct DSFieldLabel: View {
    let label: String
    var hint: String?

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
            Text(label)
                .font(DS.Font.small)
                .foregroundStyle(DS.Colors.textTertiary)
                .textCase(.uppercase)
            if let hint {
                Text(hint)
                    .font(DS.Font.micro)
                    .foregroundStyle(DS.Colors.textTertiary.opacity(DS.Opacity.muted))
            }
        }
    }
}

// MARK: - View Extensions

extension View {
    func dsCard(padding: CGFloat = DS.Spacing.lg) -> some View {
        modifier(DSCardModifier(padding: padding))
    }

    func dsPage() -> some View {
        modifier(DSPageModifier())
    }

    func dsHorizontalScrollFade(trailingWidth: CGFloat = DS.Spacing.xl) -> some View {
        modifier(DSHorizontalScrollFadeModifier(trailingWidth: trailingWidth))
    }

    func dsInteractive() -> some View {
        modifier(DSInteractive())
    }

    func dsThemedTextInput() -> some View {
        modifier(DSThemedTextInputModifier())
    }

    func dsInputField() -> some View {
        dsThemedTextInput()
            .modifier(DSInputFieldModifier())
    }

    func dsWarningCard() -> some View {
        background(DS.Colors.warningFill, in: RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .strokeBorder(DS.Colors.badgeBorder(DS.Colors.warning), lineWidth: 1)
            )
    }

    func dsBordered() -> some View {
        modifier(DSBorderedModifier())
    }

    func dsClickable() -> some View {
        modifier(DSClickable())
    }

    func dsListPanel() -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(DS.Colors.page)
    }

    func dsDetailCanvas() -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(DS.Colors.page)
    }

    func pointerOnHover() -> some View {
        onHover { hovering in
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }

    func dsMainCanvas() -> some View {
        background(DS.Colors.page)
    }

    func dsSidebarPanel() -> some View {
        background(DS.Colors.surfaceElevated)
    }

    func dsToolbarPanel() -> some View {
        background(DS.Colors.page)
    }

    /// Sidebar and global header chrome — one step above page.
    func dsChromeBar() -> some View {
        background(DS.Colors.surfaceElevated)
    }

    /// Card surface with border; use instead of ad-hoc `.background(DS.Colors.card)`.
    func dsCardSurface(cornerRadius: CGFloat = DS.Radius.md) -> some View {
        background(DS.Colors.card, in: RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(DS.Colors.border, lineWidth: 1)
            )
    }

    /// Sheets, dialogs, command palette, and quick capture.
    func dsModalChrome() -> some View {
        modifier(DSModalChromeModifier())
    }
}

// MARK: - Theme-aware input modifiers

private struct DSThemedTextInputModifier: ViewModifier {
    @Environment(\.dsPalette) private var palette
    @Bindable private var theme = DSThemeManager.shared

    func body(content: Content) -> some View {
        content
            .foregroundStyle(palette.textPrimary)
            .tint(palette.accent)
            .id(theme.themeRevision)
    }
}

private struct DSInputFieldModifier: ViewModifier {
    @Environment(\.dsPalette) private var palette

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)
            .background(palette.fillSecondary, in: RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .strokeBorder(palette.border, lineWidth: 1)
            )
    }
}

private struct DSModalChromeModifier: ViewModifier {
    @Bindable private var theme = DSThemeManager.shared

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(theme.palette.modal)
            .presentationBackground(theme.palette.modal)
            .preferredColorScheme(theme.resolvedColorScheme)
            .environment(\.dsPalette, theme.palette)
            .id(theme.themeRevision)
    }
}

// MARK: - Layout modifiers

private struct DSPageModifier: ViewModifier {
    @Environment(\.dsPalette) private var palette

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(palette.page)
    }
}

private struct DSCardModifier: ViewModifier {
    @Environment(\.dsPalette) private var palette
    let padding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(palette.card, in: RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .strokeBorder(palette.border, lineWidth: 1)
            )
            .shadow(color: palette.cardShadow, radius: 4, y: 2)
    }
}

private struct DSBorderedModifier: ViewModifier {
    @Environment(\.dsPalette) private var palette

    func body(content: Content) -> some View {
        content
            .background(palette.card, in: RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).strokeBorder(palette.border))
    }
}

private struct DSHorizontalScrollFadeModifier: ViewModifier {
    @Environment(\.dsPalette) private var palette
    let trailingWidth: CGFloat

    func body(content: Content) -> some View {
        content.mask(
            HStack(spacing: 0) {
                Rectangle().frame(maxWidth: .infinity)
                LinearGradient(
                    colors: [palette.scrollMaskOpaque, palette.scrollMaskFade],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: trailingWidth)
            }
        )
    }
}

// MARK: - Interactive Modifier

struct DSInteractive: ViewModifier {
    @State private var isHovered = false
    @State private var isPressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .background(isHovered ? DS.Colors.fillSecondary : DS.Colors.transparent, in: RoundedRectangle(cornerRadius: DS.Radius.md))
            .onHover { isHovered = $0 }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )
            .animation(DS.Animation.quick, value: isHovered)
            .animation(DS.Animation.quick, value: isPressed)
    }
}

// MARK: - Clickable Modifier

struct DSClickable: ViewModifier {
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .fill(isHovered ? DS.Colors.fillSecondary : DS.Colors.transparent)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .strokeBorder(isHovered ? DS.Colors.borderHover : DS.Colors.border, lineWidth: 1)
            )
            .onHover { isHovered = $0 }
            .animation(DS.Animation.quick, value: isHovered)
    }
}

// MARK: - Button Styles

struct PlainPointerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .onHover { hovering in
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
    }
}

extension ButtonStyle where Self == PlainPointerButtonStyle {
    static var plainPointer: PlainPointerButtonStyle {
        PlainPointerButtonStyle()
    }
}

struct DSPrimaryButtonStyle: ButtonStyle {
    @State private var isHovered = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DS.Font.caption)
            .fontWeight(.medium)
            .foregroundStyle(DS.Colors.onAccent)
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm - 1)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.sm)
                    .fill(configuration.isPressed ? DS.Colors.accent.opacity(0.85) : (isHovered ? DS.Colors.accent.opacity(0.9) : DS.Colors.accent))
            )
            .opacity(isEnabled ? 1 : DS.Opacity.disabled)
            .onHover { hovering in
                isHovered = hovering
                if hovering {
                    if isEnabled { NSCursor.pointingHand.push() } else { NSCursor.operationNotAllowed.push() }
                } else { NSCursor.pop() }
            }
            .animation(DS.Animation.quick, value: isHovered)
    }
}

struct DSSecondaryButtonStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DS.Font.caption)
            .fontWeight(.medium)
            .foregroundStyle(DS.Colors.textPrimary)
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm - 1)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.sm)
                    .fill(isHovered ? DS.Colors.fillSecondary : DS.Colors.fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.sm)
                    .strokeBorder(isHovered ? DS.Colors.borderHover : DS.Colors.border, lineWidth: 1)
            )
            .onHover { hovering in
                isHovered = hovering
                if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
            }
            .animation(DS.Animation.quick, value: isHovered)
    }
}

extension ButtonStyle where Self == DSPrimaryButtonStyle {
    static var dsPrimary: DSPrimaryButtonStyle {
        DSPrimaryButtonStyle()
    }
}

extension ButtonStyle where Self == DSSecondaryButtonStyle {
    static var dsSecondary: DSSecondaryButtonStyle {
        DSSecondaryButtonStyle()
    }
}

// MARK: - Calendar Picker

struct DSCalendarPicker: View {
    @Binding var selectedDate: Date?
    @Binding var isPresented: Bool
    @State private var displayMonth: Date = .init()

    private let calendar = Calendar.current
    private let weekdays = ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

    private var monthTitle: String {
        displayMonth.formatted(.dateTime.month(.wide).year())
    }

    private var daysInMonth: [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: displayMonth),
              let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: displayMonth)) else { return [] }
        var weekday = calendar.component(.weekday, from: firstDay)
        weekday = (weekday + 5) % 7

        var days: [Date?] = Array(repeating: nil, count: weekday)
        for day in range {
            days.append(calendar.date(byAdding: .day, value: day - 1, to: firstDay))
        }
        return days
    }

    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.sm) {
                quickButton("Today", date: Date())
                quickButton("Tomorrow", date: calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date())
                quickButton("+1w", date: calendar.date(byAdding: .weekOfYear, value: 1, to: Date()) ?? Date())
            }

            Divider()

            HStack {
                Button {
                    withAnimation(DS.Animation.quick) {
                        displayMonth = calendar.date(byAdding: .month, value: -1, to: displayMonth) ?? displayMonth
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: DS.IconSize.xs, weight: .semibold))
                        .foregroundStyle(DS.Colors.textSecondary)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plainPointer)

                Spacer()

                Text(monthTitle)
                    .font(DS.Font.caption)
                    .fontWeight(.semibold)

                Spacer()

                Button {
                    withAnimation(DS.Animation.quick) {
                        displayMonth = calendar.date(byAdding: .month, value: 1, to: displayMonth) ?? displayMonth
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: DS.IconSize.xs, weight: .semibold))
                        .foregroundStyle(DS.Colors.textSecondary)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plainPointer)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 0) {
                ForEach(weekdays, id: \.self) { day in
                    Text(day)
                        .font(DS.Font.small)
                        .foregroundStyle(DS.Colors.textTertiary)
                        .frame(height: 20)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: DS.Spacing.xxs) {
                ForEach(Array(daysInMonth.enumerated()), id: \.offset) { _, date in
                    if let date {
                        let isSelected = selectedDate.map { calendar.isDate($0, inSameDayAs: date) } ?? false
                        let isToday = calendar.isDateInToday(date)
                        let isPast = date < calendar.startOfDay(for: Date()) && !isToday

                        Button {
                            selectedDate = date
                            isPresented = false
                        } label: {
                            Text("\(calendar.component(.day, from: date))")
                                .font(DS.Font.caption)
                                .fontWeight(isToday ? .bold : .regular)
                                .foregroundStyle(
                                    isSelected ? DS.Colors.onAccent :
                                        isPast ? DS.Colors.textTertiary :
                                        isToday ? DS.Colors.accent :
                                        DS.Colors.textPrimary
                                )
                                .frame(width: DS.Layout.iconButtonSize, height: DS.Layout.iconButtonSize)
                                .background(
                                    isSelected ? DS.Colors.accent :
                                        isToday ? DS.Colors.accentFill :
                                        DS.Colors.transparent,
                                    in: Circle()
                                )
                        }
                        .buttonStyle(.plainPointer)
                    } else {
                        Text("")
                            .frame(width: DS.Layout.iconButtonSize, height: DS.Layout.iconButtonSize)
                    }
                }
            }

            if selectedDate != nil {
                Divider()
                Button {
                    selectedDate = nil
                    isPresented = false
                } label: {
                    Text("Clear date")
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Colors.danger)
                }
                .buttonStyle(.plainPointer)
            }
        }
        .padding(DS.Spacing.lg)
        .frame(width: 240)
        .onAppear {
            if let selected = selectedDate {
                displayMonth = selected
            }
        }
    }

    @ViewBuilder
    private func quickButton(_ label: String, date: Date) -> some View {
        let isSelected = selectedDate.map { calendar.isDate($0, inSameDayAs: date) } ?? false
        Button {
            selectedDate = date
            isPresented = false
        } label: {
            Text(label)
                .font(DS.Font.small)
                .foregroundStyle(isSelected ? DS.Colors.onAccent : DS.Colors.textSecondary)
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.vertical, DS.Spacing.xs)
                .background(
                    isSelected ? DS.Colors.accent : DS.Colors.fill,
                    in: RoundedRectangle(cornerRadius: DS.Radius.sm)
                )
        }
        .buttonStyle(.plainPointer)
    }
}

// MARK: - Rich Markdown Editor

import WebKit

struct DeepLinkInsertRequest: Equatable {
    let id = UUID()
    let text: String
    let url: URL
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
}

enum WikiLinkAction {
    case insertWiki(title: String)
    case insertReference(title: String, url: URL)
    case replaceWiki(newTitle: String)
    case replaceReference(newTitle: String, url: URL)
    case remove
}

struct WikiLinkEditorRequest: Equatable {
    let id = UUID()
    let action: WikiLinkAction
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
}

struct RichMarkdownEditor: NSViewRepresentable {
    @Binding var text: String
    var isReadOnly: Bool = false
    var onContentSettled: (() -> Void)?
    var onLinkClick: ((URL) -> Void)?
    var onRequestLinkInsert: ((String) -> Void)?
    var onWikiLinkClick: ((String) -> Void)?
    var linkInsertRequest: DeepLinkInsertRequest?
    var wikiLinks: [String: String] = [:]
    var linkPreviews: [String: [String: String]] = [:]
    var deadLinkUUIDs: Set<String> = []
    var onRequestDeadLinkClean: (() -> Void)?
    var cleanDeadLinksRequest: UUID?
    var wikiMode: Bool = false
    var onRequestWikiLinkInsert: (() -> Void)?
    var onRequestWikiLinkEdit: ((String) -> Void)?
    var wikiEditorRequest: WikiLinkEditorRequest?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(context.coordinator, name: "contentChanged")
        config.userContentController.add(context.coordinator, name: "editorReady")
        config.userContentController.add(context.coordinator, name: "linkClicked")
        config.userContentController.add(context.coordinator, name: "requestLinkInsert")
        config.userContentController.add(context.coordinator, name: "wikiLinkClicked")
        config.userContentController.add(context.coordinator, name: "requestWikiLinkInsert")
        config.userContentController.add(context.coordinator, name: "requestWikiLinkEdit")
        if let themeScript = DSThemeManager.shared.palette.editorThemeUserScript() {
            config.userContentController.addUserScript(themeScript)
        }

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView

        if let htmlURL = Bundle.main.url(forResource: "editor", withExtension: "html") {
            webView.loadFileURL(htmlURL, allowingReadAccessTo: htmlURL.deletingLastPathComponent())
        }
        context.coordinator.applyEditorThemeIfNeeded(force: true)

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.onLinkClick = onLinkClick
        context.coordinator.onRequestLinkInsert = onRequestLinkInsert
        context.coordinator.onWikiLinkClick = onWikiLinkClick
        context.coordinator.pendingText = text
        context.coordinator.pendingReadOnly = isReadOnly
        context.coordinator.pushIfReady()
        if wikiLinks != context.coordinator.lastWikiLinks {
            context.coordinator.lastWikiLinks = wikiLinks
            context.coordinator.updateWikiLinks(wikiLinks)
        }
        if linkPreviews != context.coordinator.lastLinkPreviews {
            context.coordinator.lastLinkPreviews = linkPreviews
            context.coordinator.updateLinkPreviews(linkPreviews)
        }
        context.coordinator.onRequestDeadLinkClean = onRequestDeadLinkClean
        if deadLinkUUIDs != context.coordinator.lastDeadLinkUUIDs {
            context.coordinator.lastDeadLinkUUIDs = deadLinkUUIDs
            context.coordinator.updateDeadLinks(deadLinkUUIDs)
        }
        if let req = cleanDeadLinksRequest, req != context.coordinator.lastCleanDeadLinksRequest {
            context.coordinator.lastCleanDeadLinksRequest = req
            context.coordinator.cleanDeadLinks()
        }
        if let req = linkInsertRequest, req != context.coordinator.lastInsertRequest {
            context.coordinator.lastInsertRequest = req
            context.coordinator.insertLink(text: req.text, url: req.url)
        }
        context.coordinator.onRequestWikiLinkInsert = onRequestWikiLinkInsert
        context.coordinator.onRequestWikiLinkEdit = onRequestWikiLinkEdit
        context.coordinator.pendingWikiMode = wikiMode
        context.coordinator.pushIfReady()
        if let req = wikiEditorRequest, req != context.coordinator.lastWikiEditorRequest {
            context.coordinator.lastWikiEditorRequest = req
            context.coordinator.performWikiAction(req.action)
        }
        context.coordinator.applyEditorThemeIfNeeded()
    }

    class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        var parent: RichMarkdownEditor
        var onLinkClick: ((URL) -> Void)?
        var onRequestLinkInsert: ((String) -> Void)?
        var onWikiLinkClick: ((String) -> Void)?
        var onRequestWikiLinkInsert: (() -> Void)?
        var onRequestWikiLinkEdit: ((String) -> Void)?
        weak var webView: WKWebView?
        var isReady = false
        var pendingText: String?
        var pendingReadOnly: Bool = false
        var pendingWikiMode: Bool = false
        var lastInsertRequest: DeepLinkInsertRequest?
        var lastWikiLinks: [String: String] = [:]
        var lastLinkPreviews: [String: [String: String]] = [:]
        var onRequestDeadLinkClean: (() -> Void)?
        var lastDeadLinkUUIDs: Set<String> = []
        var lastCleanDeadLinksRequest: UUID?
        var lastWikiMode: Bool?
        var lastWikiEditorRequest: WikiLinkEditorRequest?
        private var isReceiving = false
        private var isPushing = false
        private var lastPushed: String?
        private var lastReadOnly: Bool?
        private var hasSettled = false
        private var lastThemeRevision: Int = -1
        private var themeObserver: NSObjectProtocol?

        init(_ parent: RichMarkdownEditor) {
            self.parent = parent
            super.init()
            themeObserver = NotificationCenter.default.addObserver(
                forName: .dsThemeDidChange,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.applyEditorThemeIfNeeded(force: true)
            }
        }

        deinit {
            if let themeObserver {
                NotificationCenter.default.removeObserver(themeObserver)
            }
        }

        func applyEditorThemeIfNeeded(force: Bool = false) {
            let manager = DSThemeManager.shared
            let revision = manager.themeRevision
            guard force || revision != lastThemeRevision else { return }
            lastThemeRevision = revision
            applyEditorTheme(manager.palette)
        }

        private func applyEditorTheme(_ palette: DSThemePalette) {
            guard let webView else { return }
            webView.underPageBackgroundColor = NSColor(palette.page)
            guard let js = palette.editorThemeJavaScript() else { return }
            webView.evaluateJavaScript(js)
        }

        func pushIfReady() {
            guard isReady, let webView else { return }
            if let text = pendingText, text != lastPushed, !isReceiving, !isPushing {
                isPushing = true
                lastPushed = text
                let escaped = text
                    .replacingOccurrences(of: "\\", with: "\\\\")
                    .replacingOccurrences(of: "`", with: "\\`")
                    .replacingOccurrences(of: "$", with: "\\$")
                webView.evaluateJavaScript("window.setMarkdown(`\(escaped)`)")
                pendingText = nil
            }
            if pendingReadOnly != lastReadOnly {
                lastReadOnly = pendingReadOnly
                webView.evaluateJavaScript("window.setReadOnly(\(pendingReadOnly ? "true" : "false"))")
            }
            if pendingWikiMode != lastWikiMode {
                lastWikiMode = pendingWikiMode
                webView.evaluateJavaScript("window.setWikiMode(\(pendingWikiMode ? "true" : "false"))")
            }
        }

        func insertLink(text: String, url: URL) {
            guard let data = try? JSONSerialization.data(withJSONObject: [text, url.absoluteString]),
                  let json = String(data: data, encoding: .utf8) else { return }
            webView?.evaluateJavaScript("window.insertDeepLink(...\(json))")
        }

        private func injectLinkInterceptor() {
            let js = """
            (function() {
                if (window.__deepthinkLinkInterceptor) return;
                window.__deepthinkLinkInterceptor = true;
                document.addEventListener('click', function(e) {
                    var a = e.target.closest('a[href]');
                    if (a && a.href) {
                        e.preventDefault();
                        e.stopPropagation();
                        window.webkit.messageHandlers.linkClicked.postMessage(a.href);
                    }
                }, true);
            })();
            """
            webView?.evaluateJavaScript(js)
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }
            if url.scheme == "file" || url.scheme == "about" {
                decisionHandler(.allow)
                return
            }
            decisionHandler(.cancel)
            DispatchQueue.main.async {
                if url.scheme == "deepthink" {
                    self.onLinkClick?(url)
                } else {
                    NSWorkspace.shared.open(url)
                }
            }
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "editorReady" {
                isReady = true
                hasSettled = false
                pendingText = parent.text
                pushIfReady()
                injectLinkInterceptor()
                applyEditorThemeIfNeeded(force: true)
            } else if message.name == "contentChanged", let md = message.body as? String {
                isPushing = false
                isReceiving = true
                lastPushed = md
                parent.text = md
                isReceiving = false
                if !hasSettled {
                    hasSettled = true
                    DispatchQueue.main.async { self.parent.onContentSettled?() }
                }
            } else if message.name == "linkClicked", let urlStr = message.body as? String,
                      let url = URL(string: urlStr) {
                DispatchQueue.main.async { self.onLinkClick?(url) }
            } else if message.name == "requestLinkInsert", let type = message.body as? String {
                DispatchQueue.main.async { self.onRequestLinkInsert?(type) }
            } else if message.name == "wikiLinkClicked", let title = message.body as? String {
                DispatchQueue.main.async { self.onWikiLinkClick?(title) }
            } else if message.name == "requestWikiLinkInsert" {
                DispatchQueue.main.async { self.onRequestWikiLinkInsert?() }
            } else if message.name == "requestWikiLinkEdit", let title = message.body as? String {
                DispatchQueue.main.async { self.onRequestWikiLinkEdit?(title) }
            }
        }

        func updateWikiLinks(_ map: [String: String]) {
            guard isReady, let webView else { return }
            if let data = try? JSONSerialization.data(withJSONObject: map),
               let json = String(data: data, encoding: .utf8) {
                webView.evaluateJavaScript("window.setWikiLinks(\(json))")
            }
        }

        func updateLinkPreviews(_ map: [String: [String: String]]) {
            guard isReady, let webView else { return }
            if let data = try? JSONSerialization.data(withJSONObject: map),
               let json = String(data: data, encoding: .utf8) {
                webView.evaluateJavaScript("window.setLinkPreviews(\(json))")
            }
        }

        func updateDeadLinks(_ uuids: Set<String>) {
            guard isReady, let webView else { return }
            if let data = try? JSONSerialization.data(withJSONObject: Array(uuids)),
               let json = String(data: data, encoding: .utf8) {
                webView.evaluateJavaScript("window.setDeadLinkUUIDs(\(json))")
            }
        }

        func cleanDeadLinks() {
            webView?.evaluateJavaScript("window.cleanDeadLinks()")
        }

        func performWikiAction(_ action: WikiLinkAction) {
            guard let webView else { return }
            switch action {
            case let .insertWiki(title):
                let esc = escapeForTemplate(title)
                webView.evaluateJavaScript("window.insertWikiLink(`\(esc)`)")
            case let .insertReference(title, url):
                insertLink(text: title, url: url)
            case let .replaceWiki(newTitle):
                let esc = escapeForTemplate(newTitle)
                webView.evaluateJavaScript("window.replaceWikiLink(`\(esc)`)")
            case let .replaceReference(newTitle, url):
                guard let data = try? JSONSerialization.data(withJSONObject: [newTitle, url.absoluteString]),
                      let json = String(data: data, encoding: .utf8) else { return }
                webView.evaluateJavaScript("window.replaceWikiWithLink(...\(json))")
            case .remove:
                webView.evaluateJavaScript("window.removeWikiLink()")
            }
        }

        private func escapeForTemplate(_ s: String) -> String {
            s.replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "`", with: "\\`")
                .replacingOccurrences(of: "$", with: "\\$")
        }
    }
}

struct RichEditorToolbar: View {
    var body: some View {
        EmptyView()
    }
}

// MARK: - Toast

@Observable
final class ToastState {
    static let shared = ToastState()
    var message: String = ""
    var icon: String = "checkmark.circle.fill"
    var color: Color = DS.Colors.success
    var isShowing = false
    private var dismissTask: Task<Void, Never>?

    func show(_ text: String, icon: String = "checkmark.circle.fill", color: Color = DS.Colors.success) {
        dismissTask?.cancel()
        message = text
        self.icon = icon
        self.color = color
        withAnimation(DS.Animation.standard) { isShowing = true }
        dismissTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.5))
            withAnimation(DS.Animation.standard) { self.isShowing = false }
        }
    }

    func showError(_ text: String) {
        show(text, icon: "xmark.circle.fill", color: DS.Colors.danger)
    }
}

struct DSToastView: View {
    @State private var toast = ToastState.shared

    var body: some View {
        if toast.isShowing {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: toast.icon)
                    .font(.system(size: DS.IconSize.sm, weight: .medium))
                    .foregroundStyle(toast.color)
                Text(toast.message)
                    .font(DS.Font.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(DS.Colors.textPrimary)
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .background(DS.Colors.card, in: RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).strokeBorder(DS.Colors.border, lineWidth: 1))
            .shadow(color: DS.Colors.subtleShadow, radius: 8, y: 4)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}
