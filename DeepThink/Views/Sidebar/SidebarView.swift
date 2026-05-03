import SwiftUI
import SwiftData

struct SidebarView: View {
    @Environment(AppState.self) private var appState
    @State private var isExpanded = true

    var body: some View {
        @Bindable var appState = appState

        VStack(spacing: 0) {
            HStack {
                if isExpanded {
                    Text("DeepThink")
                        .font(DS.Font.heading)
                        .foregroundStyle(DS.Colors.textPrimary)
                }
                Spacer()
                DSToolbarButton(icon: "sidebar.left", color: DS.Colors.textTertiary, size: DS.IconSize.sm) {
                    withAnimation(DS.Animation.standard) {
                        isExpanded.toggle()
                    }
                }
            }
            .frame(height: DS.Layout.toolbarHeight)
            .padding(.horizontal, DS.Spacing.md)

            Divider()

            VStack(spacing: DS.Spacing.xs) {
                ForEach(SidebarSection.topSections) { section in
                    SidebarItem(
                        section: section,
                        isSelected: appState.selectedSection == section,
                        isExpanded: isExpanded
                    ) {
                        appState.selectedSection = section
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.top, DS.Spacing.md)

            Divider()
                .padding(.vertical, DS.Spacing.sm)

            VStack(spacing: DS.Spacing.xs) {
                ForEach(SidebarSection.mainSections) { section in
                    SidebarItem(
                        section: section,
                        isSelected: appState.selectedSection == section,
                        isExpanded: isExpanded
                    ) {
                        appState.selectedSection = section
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.sm)

            Divider()
                .padding(.vertical, DS.Spacing.sm)

            VStack(spacing: DS.Spacing.xs) {
                ForEach(SidebarSection.toolSections) { section in
                    SidebarItem(
                        section: section,
                        isSelected: appState.selectedSection == section,
                        isExpanded: isExpanded
                    ) {
                        appState.selectedSection = section
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.sm)

            Spacer()

            Divider()

            SidebarItem(
                section: .settings,
                isSelected: appState.selectedSection == .settings,
                isExpanded: isExpanded
            ) {
                appState.selectedSection = .settings
            }
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.sm)

            if isExpanded {
                Button {
                    appState.toggleCommandPalette()
                } label: {
                    HStack(spacing: DS.Spacing.sm) {
                        HStack(spacing: DS.Spacing.xs) {
                            Image(systemName: "command")
                                .font(.system(size: DS.IconSize.sm))
                            Text("K")
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                        }
                        .foregroundStyle(DS.Colors.textTertiary)
                        .padding(.horizontal, DS.Spacing.sm)
                        .padding(.vertical, 3)
                        .background(DS.Colors.fill, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.sm)
                                .strokeBorder(DS.Colors.border, lineWidth: 1)
                        )

                        Text("Command Palette")
                            .font(DS.Font.caption)
                            .foregroundStyle(DS.Colors.textSecondary)
                        Spacer()
                    }
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.sm)
                }
                .buttonStyle(.plainPointer)
            }
        }
        .frame(width: isExpanded ? DS.Layout.sidebarWidth : 52)
        .background(DS.Colors.surface)
        .animation(DS.Animation.standard, value: isExpanded)
    }
}

// MARK: - Sidebar Item

private struct SidebarItem: View {
    let section: SidebarSection
    let isSelected: Bool
    let isExpanded: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(isSelected ? DS.Colors.accent : .clear)
                    .frame(width: 3, height: 18)
                    .padding(.trailing, DS.Spacing.xs)

                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: section.icon)
                        .font(.system(size: DS.IconSize.lg, weight: .medium))
                        .foregroundStyle(isSelected ? DS.Colors.accent : DS.Colors.textTertiary)
                        .frame(width: 24, height: 24)

                    if isExpanded {
                        Text(section.rawValue)
                            .font(DS.Font.body)
                            .fontWeight(isSelected ? .semibold : .regular)
                            .foregroundStyle(isSelected ? DS.Colors.textPrimary : DS.Colors.textSecondary)
                            .lineLimit(1)
                        Spacer()
                    }
                }
                .padding(.horizontal, DS.Spacing.xs)
                .padding(.vertical, DS.Spacing.sm)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isSelected
                    ? DS.Colors.accentFill
                    : (isHovered ? DS.Colors.fillSecondary : .clear),
                in: RoundedRectangle(cornerRadius: DS.Radius.sm)
            )
        }
        .buttonStyle(.plainPointer)
        .onHover { isHovered = $0 }
        .animation(DS.Animation.quick, value: isHovered)
        .help(section.tooltip)
        .accessibilityHint(section.helpText)
    }
}
