import SwiftUI

struct CommandPaletteView: View {
    @Environment(AppState.self) private var appState
    @Environment(CommandPaletteState.self) private var state

    var body: some View {
        @Bindable var state = state

        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            VStack(spacing: 0) {
                HStack(spacing: DS.Spacing.md) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14))
                        .foregroundStyle(DS.Colors.textTertiary)

                    TextField("Type a command...", text: $state.query)
                        .textFieldStyle(.plain)
                        .font(.system(size: 16))
                        .onSubmit {
                            if state.executeSelected() { dismiss() }
                        }
                }
                .padding(DS.Spacing.lg)

                Divider().opacity(0.5)

                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            let commands = state.filteredCommands
                            ForEach(Array(commands.enumerated()), id: \.element.id) { index, command in
                                PaletteRow(command: command, isSelected: index == state.selectedIndex)
                                    .id(command.id)
                                    .onTapGesture {
                                        command.action()
                                        dismiss()
                                    }
                            }

                            if commands.isEmpty {
                                Text("No matching commands")
                                    .font(DS.Font.body)
                                    .foregroundStyle(DS.Colors.textTertiary)
                                    .frame(maxWidth: .infinity)
                                    .padding(DS.Spacing.xxl)
                            }
                        }
                        .padding(DS.Spacing.sm)
                    }
                    .frame(maxHeight: 360)
                    .onChange(of: state.selectedIndex) { _, newValue in
                        let commands = state.filteredCommands
                        if commands.indices.contains(newValue) {
                            proxy.scrollTo(commands[newValue].id, anchor: .center)
                        }
                    }
                }

                Divider().opacity(0.5)

                HStack(spacing: DS.Spacing.lg) {
                    HStack(spacing: DS.Spacing.xs) {
                        KeyHint("↑↓")
                        Text("navigate")
                    }
                    HStack(spacing: DS.Spacing.xs) {
                        KeyHint("↵")
                        Text("select")
                    }
                    HStack(spacing: DS.Spacing.xs) {
                        KeyHint("esc")
                        Text("close")
                    }
                }
                .font(DS.Font.small)
                .foregroundStyle(DS.Colors.textTertiary)
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.sm)
            }
            .frame(width: 520)
            .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.lg))
            .overlay {
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.25), radius: 30, y: 10)
            .padding(.top, 80)
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .onKeyPress(.upArrow) { state.moveUp(); return .handled }
        .onKeyPress(.downArrow) { state.moveDown(); return .handled }
        .onKeyPress(.escape) { dismiss(); return .handled }
        .onAppear { state.reset() }
    }

    private func dismiss() {
        appState.toggleCommandPalette()
    }
}

private struct PaletteRow: View {
    let command: Command
    let isSelected: Bool

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: command.icon)
                .font(.system(size: 12, weight: .medium))
                .frame(width: 20)
                .foregroundStyle(isSelected ? .white : DS.Colors.textSecondary)

            Text(command.title)
                .font(DS.Font.body)
                .foregroundStyle(isSelected ? .white : DS.Colors.textPrimary)

            if let section = Optional(command.section), !section.isEmpty {
                Text(section)
                    .font(DS.Font.small)
                    .foregroundStyle(isSelected ? .white.opacity(0.5) : DS.Colors.textTertiary)
            }

            Spacer()

            if let shortcut = command.shortcut {
                Text(shortcut)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(isSelected ? .white.opacity(0.7) : DS.Colors.textTertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        (isSelected ? AnyShapeStyle(.white.opacity(0.15)) : AnyShapeStyle(DS.Colors.border)),
                        in: RoundedRectangle(cornerRadius: 4)
                    )
                }
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
        .background(
            isSelected
                ? AnyShapeStyle(LinearGradient(colors: [DS.Colors.accent, DS.Colors.accent.opacity(0.8)], startPoint: .leading, endPoint: .trailing))
                : AnyShapeStyle(.clear),
            in: RoundedRectangle(cornerRadius: DS.Radius.sm)
        )
        .contentShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
    }
}

private struct KeyHint: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .medium, design: .rounded))
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(DS.Colors.border, in: RoundedRectangle(cornerRadius: 3))
    }
}
