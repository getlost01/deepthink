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

    enum IconSize {
        static let xs: CGFloat = 9
        static let sm: CGFloat = 11
        static let md: CGFloat = 13
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
    }

    enum Font {
        static let hero: SwiftUI.Font = .system(size: 28, weight: .bold, design: .default)
        static let title: SwiftUI.Font = .system(size: 20, weight: .semibold)
        static let heading: SwiftUI.Font = .system(size: 15, weight: .semibold)
        static let bodyLarge: SwiftUI.Font = .system(size: 14)
        static let body: SwiftUI.Font = .system(size: 13)
        static let caption: SwiftUI.Font = .system(size: 11)
        static let tiny: SwiftUI.Font = .system(size: 10)
        static let code: SwiftUI.Font = .system(size: 13, weight: .regular, design: .monospaced)
        static let mono: SwiftUI.Font = .system(size: 13, weight: .regular, design: .monospaced)
        static let monoSmall: SwiftUI.Font = .system(size: 11, weight: .regular, design: .monospaced)
        static let terminal: SwiftUI.Font = .system(size: 13, weight: .regular, design: .monospaced)

        static let subtitle: SwiftUI.Font = .system(size: 16, weight: .medium)
        static let detailTitle: SwiftUI.Font = .system(size: 18, weight: .semibold)
        static let sectionLabel: SwiftUI.Font = .system(size: 12, weight: .medium)
    }

    enum Colors {
        static let accent = Color.accentColor
        static let surface = Color(nsColor: .controlBackgroundColor)
        static let surfaceElevated = Color(nsColor: .windowBackgroundColor)
        static let border = Color.primary.opacity(0.10)
        static let borderStrong = Color.primary.opacity(0.15)
        static let borderSubtle = Color.primary.opacity(0.06)
        static let textPrimary = Color.primary
        static let textSecondary = Color.secondary
        static let textTertiary = Color.primary.opacity(0.35)

        static let success = Color.green
        static let warning = Color.orange
        static let error = Color.red
        static let info = Color.blue

        static let hoverBg = Color.primary.opacity(0.06)
        static let subtleBg = Color.primary.opacity(0.04)
        static let inputBg = Color.primary.opacity(0.05)
        static let selectedBg = Color.accentColor.opacity(0.08)
    }

    enum Layout {
        static let sidebarWidth: CGFloat = 200
        static let listPanelWidth: CGFloat = 280
        static let toolbarHeight: CGFloat = 48
        static let headerHeight: CGFloat = 48
    }

    enum Animation {
        static let quick: SwiftUI.Animation = .easeInOut(duration: 0.15)
        static let standard: SwiftUI.Animation = .easeInOut(duration: 0.25)
        static let spring: SwiftUI.Animation = .spring(duration: 0.3, bounce: 0.15)
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
        .frame(height: DS.Layout.headerHeight)
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
            .background(.background, in: RoundedRectangle(cornerRadius: DS.Radius.lg))
            .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
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
                    .buttonStyle(.plainPointer)
            }
        }
    }
}

// MARK: - List Panel Header (legacy, prefer DSPageHeader)

struct DSListHeader: View {
    let title: String
    var trailing: AnyView? = nil

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            Text(title)
                .font(DS.Font.heading)
            Spacer()
            if let trailing { trailing }
        }
        .frame(height: DS.Layout.headerHeight)
        .padding(.horizontal, DS.Spacing.lg)
    }
}

// MARK: - Toolbar Bar

struct DSToolbarBar<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            content()
        }
        .frame(height: DS.Layout.toolbarHeight)
        .padding(.horizontal, DS.Spacing.md)
        .background(.bar)
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
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: size * 0.25))
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
            .background(color.opacity(0.12), in: Capsule())
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
        .background(DS.Colors.inputBg, in: RoundedRectangle(cornerRadius: DS.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .strokeBorder(DS.Colors.borderSubtle, lineWidth: 1)
        )
    }
}

// MARK: - Action Button

struct DSActionButton: View {
    let title: String
    let icon: String
    var color: Color = DS.Colors.accent
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
            .background(color.opacity(isHovered ? 0.15 : 0.1), in: RoundedRectangle(cornerRadius: DS.Radius.sm))
        }
        .buttonStyle(.plainPointer)
        .onHover { isHovered = $0 }
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
        VStack(spacing: DS.Spacing.xl) {
            Image(systemName: icon)
                .font(.system(size: 36, weight: .light))
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
                        .frame(maxWidth: 320)
                }
            }

            if let action {
                Button(action: action) {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "plus")
                            .font(.system(size: DS.IconSize.xs, weight: .medium))
                        Text(actionTitle)
                            .font(DS.Font.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.sm)
                    .background(DS.Colors.accent, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                }
                .buttonStyle(.plainPointer)
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

// MARK: - Toolbar Style (legacy)

struct DSToolbar<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            content()
        }
        .frame(height: DS.Layout.toolbarHeight)
        .padding(.horizontal, DS.Spacing.xl)
        .background(.bar)
    }
}

// MARK: - Interactive Modifier

struct DSInteractive: ViewModifier {
    @State private var isHovered = false
    @State private var isPressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .background(isHovered ? DS.Colors.hoverBg : .clear, in: RoundedRectangle(cornerRadius: DS.Radius.md))
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

// MARK: - Clickable Card/Row Modifier

struct DSClickable: ViewModifier {
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .fill(isHovered ? DS.Colors.hoverBg : .clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .strokeBorder(isHovered ? DS.Colors.borderStrong : DS.Colors.border, lineWidth: 1)
            )
            .onHover { isHovered = $0 }
            .animation(DS.Animation.quick, value: isHovered)
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
                .background(isHovered ? DS.Colors.hoverBg : .clear, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
        }
        .buttonStyle(.plainPointer)
        .onHover { isHovered = $0 }
        .animation(DS.Animation.quick, value: isHovered)
        .accessibilityLabel(label ?? icon)
    }
}

// MARK: - Stat Chip (shared)

struct DSStatChip: View {
    let label: String
    let value: String
    let icon: String
    var color: Color = DS.Colors.textSecondary

    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: DS.IconSize.xs, weight: .medium))
            Text(value)
                .font(DS.Font.caption)
                .fontWeight(.medium)
        }
        .foregroundStyle(color)
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
        .background(DS.Colors.inputBg, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.sm)
                .strokeBorder(DS.Colors.borderSubtle, lineWidth: 1)
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
                .font(DS.Font.sectionLabel)
                .foregroundStyle(DS.Colors.textTertiary)
                .textCase(.uppercase)

            TextField(placeholder.isEmpty ? label : placeholder, text: $text, axis: axis)
                .textFieldStyle(.plain)
                .font(DS.Font.body)
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.md)
                .background(DS.Colors.inputBg, in: RoundedRectangle(cornerRadius: DS.Radius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.md)
                        .strokeBorder(DS.Colors.borderSubtle, lineWidth: 1)
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
                .font(DS.Font.sectionLabel)
                .foregroundStyle(DS.Colors.textTertiary)
                .textCase(.uppercase)

            TextEditor(text: $text)
                .font(DS.Font.body)
                .scrollContentBackground(.hidden)
                .frame(minHeight: minHeight)
                .padding(DS.Spacing.md)
                .background(DS.Colors.inputBg, in: RoundedRectangle(cornerRadius: DS.Radius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.md)
                        .strokeBorder(DS.Colors.borderSubtle, lineWidth: 1)
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
                .font(DS.Font.sectionLabel)
                .foregroundStyle(DS.Colors.textTertiary)
                .textCase(.uppercase)

            Picker("", selection: $selection) {
                content()
            }
            .pickerStyle(.menu)
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.xs)
            .background(DS.Colors.inputBg, in: RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .strokeBorder(DS.Colors.borderSubtle, lineWidth: 1)
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
                    .font(DS.Font.tiny)
                    .fontWeight(.medium)
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

// MARK: - View Extensions

extension View {
    func dsCard(padding: CGFloat = DS.Spacing.lg) -> some View {
        self
            .padding(padding)
            .background(.background, in: RoundedRectangle(cornerRadius: DS.Radius.lg))
            .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
    }

    func dsGlass(padding: CGFloat = DS.Spacing.lg) -> some View {
        self
            .padding(padding)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.lg))
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

    func dsInteractive() -> some View {
        modifier(DSInteractive())
    }

    func dsInputField() -> some View {
        self
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)
            .background(DS.Colors.inputBg, in: RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .strokeBorder(DS.Colors.borderSubtle, lineWidth: 1)
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
            .frame(width: DS.Layout.listPanelWidth)
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

// MARK: - Pointer Cursor Button Style

struct PointerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onHover { hovering in
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
    }
}

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

// MARK: - Custom Calendar Picker

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
            // Quick options
            HStack(spacing: DS.Spacing.sm) {
                quickButton("Today", date: Date())
                quickButton("Tomorrow", date: calendar.date(byAdding: .day, value: 1, to: Date())!)
                quickButton("+1w", date: calendar.date(byAdding: .weekOfYear, value: 1, to: Date())!)
            }

            Divider()

            // Month nav
            HStack {
                Button {
                    withAnimation(DS.Animation.quick) {
                        displayMonth = calendar.date(byAdding: .month, value: -1, to: displayMonth)!
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 10, weight: .semibold))
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
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(DS.Colors.textSecondary)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plainPointer)
            }

            // Weekday headers
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 0) {
                ForEach(weekdays, id: \.self) { day in
                    Text(day)
                        .font(DS.Font.tiny)
                        .fontWeight(.medium)
                        .foregroundStyle(DS.Colors.textTertiary)
                        .frame(height: 20)
                }
            }

            // Days grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 2) {
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
                                    isSelected ? .white :
                                    isPast ? DS.Colors.textTertiary :
                                    isToday ? DS.Colors.accent :
                                    DS.Colors.textPrimary
                                )
                                .frame(width: 28, height: 28)
                                .background(
                                    isSelected ? DS.Colors.accent :
                                    isToday ? DS.Colors.accent.opacity(0.1) :
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
                        .foregroundStyle(DS.Colors.error)
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
                .font(DS.Font.tiny)
                .fontWeight(.medium)
                .foregroundStyle(isSelected ? .white : DS.Colors.textSecondary)
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.vertical, DS.Spacing.xs)
                .background(
                    isSelected ? DS.Colors.accent : DS.Colors.inputBg,
                    in: RoundedRectangle(cornerRadius: DS.Radius.sm)
                )
        }
        .buttonStyle(.plainPointer)
    }
}

// MARK: - Rich Markdown Editor (Tiptap + WKWebView, locally bundled)

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
