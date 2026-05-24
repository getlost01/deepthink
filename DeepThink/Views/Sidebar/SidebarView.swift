import SwiftData
import SwiftUI

struct SidebarView: View {
    @Environment(AppState.self) private var appState
    @State private var isExpanded = true
    @Query(filter: #Predicate<TaskItem> { !$0.isArchived }) private var allTasks: [TaskItem]
    @Query(filter: #Predicate<Reminder> { !$0.isCompleted }) private var activeReminders: [Reminder]

    private var overdueTaskCount: Int {
        let now = Date()
        return allTasks.count(where: { t in
            guard let due = t.dueDate else { return false }
            return due < now && t.status != .done && t.status != .cancelled
        })
    }

    private var todayReminderCount: Int {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let end = cal.date(byAdding: .day, value: 1, to: start) ?? Date()
        return activeReminders.count(where: { r in
            guard let date = r.reminderDate else { return false }
            return date >= start && date < end
        })
    }

    private func badge(for section: SidebarSection) -> Int {
        switch section {
        case .reminders: todayReminderCount
        case .workspace: overdueTaskCount
        default: 0
        }
    }

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
                        isExpanded: isExpanded,
                        badge: badge(for: section)
                    ) {
                        appState.navigate(to: section)
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.sm)

            Divider()
                .padding(.bottom, DS.Spacing.xs)

            VStack(spacing: DS.Spacing.xs) {
                ForEach(SidebarSection.mainSections) { section in
                    SidebarItem(
                        section: section,
                        isSelected: appState.selectedSection == section,
                        isExpanded: isExpanded,
                        badge: badge(for: section)
                    ) {
                        appState.navigate(to: section)
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.sm)

            Divider()
                .padding(.vertical, DS.Spacing.xs)

            VStack(spacing: DS.Spacing.xs) {
                ForEach(SidebarSection.toolSections) { section in
                    SidebarItem(
                        section: section,
                        isSelected: appState.selectedSection == section,
                        isExpanded: isExpanded,
                        badge: badge(for: section)
                    ) {
                        appState.navigate(to: section)
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
        }
        .frame(width: isExpanded ? DS.Layout.sidebarWidth : DS.Layout.sidebarCollapsedWidth)
        .dsChromeBar()
        .animation(DS.Animation.standard, value: isExpanded)
    }
}

// MARK: - Sidebar Item

private struct SidebarItem: View {
    let section: SidebarSection
    let isSelected: Bool
    let isExpanded: Bool
    var badge: Int = 0
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: section.icon)
                    .font(.system(size: DS.IconSize.md, weight: .medium))
                    .foregroundStyle(isSelected ? DS.Colors.accent : DS.Colors.textTertiary)
                    .frame(width: DS.Layout.sidebarIconSlot, height: DS.Layout.sidebarIconSlot)

                if isExpanded {
                    Text(section.rawValue)
                        .font(DS.Font.bodySmall)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .foregroundStyle(isSelected ? DS.Colors.textPrimary : DS.Colors.textSecondary)
                        .lineLimit(1)
                    Spacer()
                    if badge > 0 {
                        Text("\(badge)")
                            .font(DS.Font.badge)
                            .fontWeight(.bold)
                            .foregroundStyle(DS.Colors.onAccent)
                            .padding(.horizontal, DS.Spacing.xs)
                            .padding(.vertical, DS.Spacing.xxs)
                            .background(DS.Colors.danger, in: Capsule())
                    }
                } else if badge > 0 {
                    Circle()
                        .fill(DS.Colors.danger)
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xs2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isSelected
                    ? DS.Colors.accentFill
                    : (isHovered ? DS.Colors.fillSecondary : DS.Colors.transparent),
                in: RoundedRectangle(cornerRadius: DS.Radius.sm)
            )
            .overlay(alignment: .leading) {
                if isSelected {
                    Capsule()
                        .fill(DS.Colors.accent)
                        .frame(width: 2.5)
                        .padding(.vertical, DS.Spacing.xs)
                        .padding(.leading, DS.Spacing.xxxs)
                }
            }
        }
        .buttonStyle(.plainPointer)
        .onHover { isHovered = $0 }
        .animation(DS.Animation.quick, value: isHovered)
        .help(section.tooltip)
        .accessibilityHint(section.helpText)
    }
}
