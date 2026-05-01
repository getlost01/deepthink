import SwiftUI
import SwiftData

struct SidebarView: View {
    @Environment(AppState.self) private var appState
    @State private var isExpanded = true

    private var mainSections: [SidebarSection] {
        [.workspace, .ai, .terminal, .docs]
    }

    var body: some View {
        @Bindable var appState = appState

        VStack(spacing: 0) {
            HStack {
                if isExpanded {
                    Text("DeepThink")
                        .font(DS.Font.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(DS.Colors.textPrimary)
                }
                Spacer()
                DSToolbarButton(icon: "sidebar.left", color: DS.Colors.textTertiary, size: DS.IconSize.sm) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.md)

            Divider()

            VStack(spacing: DS.Spacing.xs) {
                ForEach(mainSections) { section in
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
                                .font(.system(size: DS.IconSize.xs))
                            Text("K")
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                        }
                        .foregroundStyle(DS.Colors.textTertiary)
                        .padding(.horizontal, DS.Spacing.xs)
                        .padding(.vertical, 2)
                        .background(DS.Colors.border, in: RoundedRectangle(cornerRadius: DS.Spacing.xs))

                        Text("Command Palette")
                            .font(DS.Font.caption)
                            .foregroundStyle(DS.Colors.textSecondary)
                        Spacer()
                    }
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.sm)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: isExpanded ? DS.Layout.sidebarWidth : 52)
        .background(DS.Colors.surface)
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
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
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: section.icon)
                    .font(.system(size: DS.IconSize.md, weight: .medium))
                    .foregroundStyle(isSelected ? section.color : DS.Colors.textSecondary)
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
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isSelected
                    ? section.color.opacity(0.1)
                    : (isHovered ? DS.Colors.hoverBg : .clear),
                in: RoundedRectangle(cornerRadius: DS.Radius.sm)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(isExpanded ? "" : section.rawValue)
    }
}
