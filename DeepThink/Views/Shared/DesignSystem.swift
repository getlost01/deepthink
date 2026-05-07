import SwiftUI

// MARK: - Design Tokens

enum DS {
    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    enum Radius {
        static let sm: CGFloat = 6
        static let md: CGFloat = 8
        static let lg: CGFloat = 12
        static let xl: CGFloat = 14
        static let pill: CGFloat = 20
    }

    enum IconSize {
        static let xs: CGFloat = 9
        static let sm: CGFloat = 12
        static let md: CGFloat = 14
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
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
    }

    enum Colors {
        static let accent = Color(hue: 0.58, saturation: 0.72, brightness: 0.98)
        static let accentFill = accent.opacity(0.22)
        static let accentGradient = LinearGradient(
            colors: [Color(hue: 0.56, saturation: 0.60, brightness: 1.0), Color(hue: 0.61, saturation: 0.78, brightness: 0.92)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        static let onAccent = Color.white

        static let surface = Color(nsColor: .controlBackgroundColor)
        static let surfaceElevated = Color(nsColor: .textBackgroundColor)
        static let fill = Color(hue: 0.58, saturation: 0.06, brightness: 0.50).opacity(0.07)
        static let fillSecondary = Color(hue: 0.58, saturation: 0.08, brightness: 0.50).opacity(0.10)

        static let border = Color.primary.opacity(0.10)
        static let borderHover = Color.primary.opacity(0.18)
        static let borderFocused = accent.opacity(0.50)

        static let textPrimary = Color.primary
        static let textSecondary = Color.secondary
        static let textTertiary = Color.primary.opacity(0.45)

        static let success = Color(hue: 0.38, saturation: 0.72, brightness: 0.82)
        static let warning = Color(hue: 0.09, saturation: 0.78, brightness: 0.95)
        static let danger = Color(hue: 0.0, saturation: 0.72, brightness: 0.90)
        static let knowledge = Color(hue: 0.75, saturation: 0.55, brightness: 0.88)

        static let info = Color(hue: 0.58, saturation: 0.65, brightness: 0.95)
        static let teal = Color(hue: 0.48, saturation: 0.60, brightness: 0.85)
        static let purple = Color(hue: 0.75, saturation: 0.55, brightness: 0.90)
        static let amber = Color(hue: 0.09, saturation: 0.72, brightness: 0.95)
        static let lime = Color(hue: 0.35, saturation: 0.62, brightness: 0.82)
        static let slate = Color(hue: 0.58, saturation: 0.15, brightness: 0.58)
        static let gold = Color(hue: 0.12, saturation: 0.75, brightness: 0.92)

        static let terminal = Color(NSColor(red: 0.1, green: 0.1, blue: 0.13, alpha: 1.0))
        static let terminalNS = NSColor(red: 0.1, green: 0.1, blue: 0.13, alpha: 1.0)

        static let cardShadow = Color.black.opacity(0.06)
        static let modalShadow = Color.black.opacity(0.25)
        static let subtleShadow = Color.black.opacity(0.10)
        static let overlayBg = Color.black.opacity(Opacity.overlayBg)
    }

    enum Opacity {
        static let hover: Double = 0.08
        static let subtle: Double = 0.12
        static let disabled: Double = 0.5
        static let overlayBg: Double = 0.35
    }

    enum Layout {
        static let sidebarWidth: CGFloat = 200
        static let panelWidth: CGFloat = 300
        static let toolbarHeight: CGFloat = 44
        static let rowHeight: CGFloat = 36
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

    init(title: String, @ViewBuilder trailing: @escaping () -> Trailing) {
        self.title = title
        self.trailing = trailing
    }

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
    }
}

extension DSPageHeader where Trailing == EmptyView {
    init(title: String) {
        self.title = title
        self.trailing = { EmptyView() }
    }
}

// MARK: - Card

struct DSCard<Content: View>: View {
    var padding: CGFloat = DS.Spacing.lg
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .background(.background, in: RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .strokeBorder(DS.Colors.border, lineWidth: 1)
            )
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
        .background(DS.Colors.surfaceElevated)
    }
}

// MARK: - Tab Button

struct DSTabButton: View {
    let title: String
    var icon: String? = nil
    let isSelected: Bool
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
                }
                .foregroundStyle(isSelected ? DS.Colors.textPrimary : (isHovered ? DS.Colors.textPrimary : DS.Colors.textSecondary))
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.sm)
                .background(isHovered && !isSelected ? DS.Colors.fillSecondary : .clear, in: RoundedRectangle(cornerRadius: DS.Radius.sm))

                Rectangle()
                    .fill(isSelected ? DS.Colors.accent : .clear)
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
    var size: CGFloat = 28

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: size * 0.45, weight: .medium))
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .background(DS.Colors.fill, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
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
            .padding(.vertical, 3)
            .background(color.opacity(0.10), in: Capsule())
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
                .font(.system(size: DS.IconSize.md))

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(DS.Font.body)
                .onSubmit { onSubmit?() }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.sm + 2)
        .background(DS.Colors.fillSecondary, in: RoundedRectangle(cornerRadius: DS.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .strokeBorder(DS.Colors.border, lineWidth: 1)
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
    var subtitle: String? = nil
    var hint: String? = nil
    var action: (() -> Void)? = nil
    var actionTitle: String = "Get Started"

    var body: some View {
        VStack(spacing: DS.Spacing.xl) {
            Image(systemName: icon)
                .font(.system(size: 32, weight: .light))
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
    var subtitle: String? = nil
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
    var label: String? = nil
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size, weight: .medium))
                .foregroundStyle(isHovered ? DS.Colors.textPrimary : color)
                .frame(width: 28, height: 28)
                .background(isHovered ? DS.Colors.fillSecondary : .clear, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
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
                .frame(width: 28, height: 28)
                .background(isOn ? DS.Colors.accentFill : (isHovered ? DS.Colors.fillSecondary : DS.Colors.fill), in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.sm)
                        .strokeBorder(isOn ? DS.Colors.accent.opacity(0.4) : (isHovered ? DS.Colors.borderHover : DS.Colors.border), lineWidth: 1)
                )
                .overlay(alignment: .topTrailing) {
                    if count > 0 {
                        Text(count > 99 ? "99+" : "\(count)")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 3)
                            .frame(minWidth: 14, minHeight: 14)
                            .background(isOn ? DS.Colors.accent : DS.Colors.textSecondary, in: Capsule())
                            .offset(x: 5, y: -5)
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
                .frame(width: 28, height: 28)
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
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(label)
                .font(DS.Font.small)
                .foregroundStyle(DS.Colors.textTertiary)
                .textCase(.uppercase)

            TextField(placeholder.isEmpty ? label : placeholder, text: $text, axis: axis)
                .textFieldStyle(.plain)
                .font(DS.Font.body)
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.md)
                .background(DS.Colors.fillSecondary, in: RoundedRectangle(cornerRadius: DS.Radius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.md)
                        .strokeBorder(DS.Colors.border, lineWidth: 1)
                )
        }
    }
}

struct DSLabeledTextEditor: View {
    let label: String
    @Binding var text: String
    var minHeight: CGFloat = 200

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(label)
                .font(DS.Font.small)
                .foregroundStyle(DS.Colors.textTertiary)
                .textCase(.uppercase)

            TextEditor(text: $text)
                .font(DS.Font.body)
                .scrollContentBackground(.hidden)
                .frame(minHeight: minHeight)
                .padding(DS.Spacing.md)
                .background(DS.Colors.fillSecondary, in: RoundedRectangle(cornerRadius: DS.Radius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.md)
                        .strokeBorder(DS.Colors.border, lineWidth: 1)
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
    var label: String? = nil

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

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: DS.IconSize.md, weight: .medium))
                .foregroundStyle(color)
                .frame(width: 28, height: 28)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: DS.Radius.sm))

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
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.Colors.fill)
    }
}

// MARK: - Field Label

struct DSFieldLabel: View {
    let label: String
    var hint: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
            Text(label)
                .font(DS.Font.small)
                .foregroundStyle(DS.Colors.textTertiary)
                .textCase(.uppercase)
            if let hint {
                Text(hint)
                    .font(DS.Font.micro)
                    .foregroundStyle(DS.Colors.textTertiary.opacity(0.7))
            }
        }
    }
}

// MARK: - View Extensions

extension View {
    func dsCard(padding: CGFloat = DS.Spacing.lg) -> some View {
        self
            .padding(padding)
            .background(.background, in: RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .strokeBorder(DS.Colors.border, lineWidth: 1)
            )
            .shadow(color: DS.Colors.cardShadow, radius: 4, y: 2)
    }

    func dsPage() -> some View {
        self
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color(nsColor: .windowBackgroundColor))
    }

    func dsInteractive() -> some View {
        modifier(DSInteractive())
    }

    func dsInputField() -> some View {
        self
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)
            .background(DS.Colors.fillSecondary, in: RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .strokeBorder(DS.Colors.border, lineWidth: 1)
            )
    }

    func dsBordered() -> some View {
        self
            .background(.background, in: RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).strokeBorder(DS.Colors.border))
    }

    func dsClickable() -> some View {
        modifier(DSClickable())
    }

    func dsListPanel() -> some View {
        self
            .frame(width: DS.Layout.panelWidth)
    }

    func pointerOnHover() -> some View {
        self.onHover { hovering in
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

// MARK: - Interactive Modifier

struct DSInteractive: ViewModifier {
    @State private var isHovered = false
    @State private var isPressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .background(isHovered ? DS.Colors.fillSecondary : .clear, in: RoundedRectangle(cornerRadius: DS.Radius.md))
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
                    .fill(isHovered ? DS.Colors.fillSecondary : .clear)
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
    static var plainPointer: PlainPointerButtonStyle { PlainPointerButtonStyle() }
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
    static var dsPrimary: DSPrimaryButtonStyle { DSPrimaryButtonStyle() }
}

extension ButtonStyle where Self == DSSecondaryButtonStyle {
    static var dsSecondary: DSSecondaryButtonStyle { DSSecondaryButtonStyle() }
}

// MARK: - Calendar Picker

struct DSCalendarPicker: View {
    @Binding var selectedDate: Date?
    @Binding var isPresented: Bool
    @State private var displayMonth: Date = Date()

    private let calendar = Calendar.current
    private let weekdays = ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

    private var monthTitle: String {
        displayMonth.formatted(.dateTime.month(.wide).year())
    }

    private var daysInMonth: [Date?] {
        let range = calendar.range(of: .day, in: .month, for: displayMonth)!
        let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: displayMonth))!
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
                quickButton("Tomorrow", date: calendar.date(byAdding: .day, value: 1, to: Date())!)
                quickButton("+1w", date: calendar.date(byAdding: .weekOfYear, value: 1, to: Date())!)
            }

            Divider()

            HStack {
                Button {
                    withAnimation(DS.Animation.quick) {
                        displayMonth = calendar.date(byAdding: .month, value: -1, to: displayMonth)!
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
                        displayMonth = calendar.date(byAdding: .month, value: 1, to: displayMonth)!
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
                                .frame(width: 28, height: 28)
                                .background(
                                    isSelected ? DS.Colors.accent :
                                    isToday ? DS.Colors.accentFill :
                                    .clear,
                                    in: Circle()
                                )
                        }
                        .buttonStyle(.plainPointer)
                    } else {
                        Text("")
                            .frame(width: 28, height: 28)
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

struct RichMarkdownEditor: NSViewRepresentable {
    @Binding var text: String

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(context.coordinator, name: "contentChanged")
        config.userContentController.add(context.coordinator, name: "editorReady")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        context.coordinator.webView = webView

        if let htmlURL = Bundle.main.url(forResource: "editor", withExtension: "html") {
            webView.loadFileURL(htmlURL, allowingReadAccessTo: htmlURL.deletingLastPathComponent())
        }

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.pendingText = text
        context.coordinator.pushIfReady()
    }

    class Coordinator: NSObject, WKScriptMessageHandler {
        var parent: RichMarkdownEditor
        weak var webView: WKWebView?
        var isReady = false
        var pendingText: String?
        private var isReceiving = false
        private var lastPushed: String?

        init(_ parent: RichMarkdownEditor) {
            self.parent = parent
        }

        func pushIfReady() {
            guard isReady, let webView = webView, let text = pendingText else { return }
            if text == lastPushed || isReceiving { return }
            lastPushed = text
            let escaped = text
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "`", with: "\\`")
                .replacingOccurrences(of: "$", with: "\\$")
            webView.evaluateJavaScript("window.setMarkdown(`\(escaped)`)")
            pendingText = nil
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "editorReady" {
                isReady = true
                pendingText = parent.text
                pushIfReady()
            } else if message.name == "contentChanged", let md = message.body as? String {
                isReceiving = true
                lastPushed = md
                parent.text = md
                isReceiving = false
            }
        }
    }
}

struct RichEditorToolbar: View {
    var body: some View { EmptyView() }
}
