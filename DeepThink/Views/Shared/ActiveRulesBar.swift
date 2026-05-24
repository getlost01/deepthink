import SwiftUI

struct ActiveRulesBar: View {
    let rules: [RuleFile]
    @Binding var disabledRuleIDs: Set<String>
    var onToggle: ((String) -> Void)?

    @State private var showPopover = false

    private var activeCount: Int {
        rules.count(where: { !disabledRuleIDs.contains($0.id) })
    }

    var body: some View {
        if !rules.isEmpty {
            Button { showPopover.toggle() } label: {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: DS.IconSize.xs, weight: .semibold))
                        .foregroundStyle(activeCount > 0 ? DS.Colors.accent : DS.Colors.textTertiary)
                    Text(countLabel)
                        .font(DS.Font.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(activeCount > 0 ? DS.Colors.textPrimary : DS.Colors.textTertiary)
                    Image(systemName: "chevron.down")
                        .font(DS.Font.badge)
                        .foregroundStyle(DS.Colors.textTertiary)
                }
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.vertical, DS.Spacing.xs + 1)
                .background(DS.Colors.fill, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
            }
            .buttonStyle(.plainPointer)
            .popover(isPresented: $showPopover, arrowEdge: .bottom) {
                RulesDropdown(
                    rules: rules,
                    disabledRuleIDs: $disabledRuleIDs,
                    onToggle: onToggle
                )
            }
        }
    }

    private var countLabel: String {
        activeCount == rules.count ? "\(rules.count) Rules" : "\(activeCount)/\(rules.count) Rules"
    }
}

// MARK: - Dropdown Content

private struct RulesDropdown: View {
    let rules: [RuleFile]
    @Binding var disabledRuleIDs: Set<String>
    var onToggle: ((String) -> Void)?

    private var grouped: [(category: String, rules: [RuleFile])] {
        let cats = Array(Set(rules.map(\.category))).sorted()
        return cats.map { cat in (cat, rules.filter { $0.category == cat }) }
    }

    private var allActive: Bool {
        rules.allSatisfy { !disabledRuleIDs.contains($0.id) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: DS.IconSize.xs, weight: .semibold))
                    .foregroundStyle(DS.Colors.accent)
                Text("Rules")
                    .font(DS.Font.body)
                    .fontWeight(.semibold)
                    .foregroundStyle(DS.Colors.textPrimary)
                Spacer()
                Button {
                    if allActive {
                        rules.forEach { disabledRuleIDs.insert($0.id) }
                    } else {
                        rules.forEach { disabledRuleIDs.remove($0.id) }
                    }
                } label: {
                    Text(allActive ? "Disable All" : "Enable All")
                        .font(DS.Font.small)
                        .foregroundStyle(DS.Colors.accent)
                }
                .buttonStyle(.plainPointer)
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(grouped, id: \.category) { group in
                        if grouped.count > 1 {
                            Text(group.category.uppercased())
                                .font(DS.Font.micro)
                                .foregroundStyle(DS.Colors.textTertiary)
                                .padding(.horizontal, DS.Spacing.md)
                                .padding(.top, DS.Spacing.sm)
                                .padding(.bottom, DS.Spacing.xxs)
                        }
                        ForEach(group.rules) { rule in
                            RuleDropdownRow(
                                rule: rule,
                                isActive: !disabledRuleIDs.contains(rule.id)
                            ) {
                                if let onToggle {
                                    onToggle(rule.id)
                                } else {
                                    if disabledRuleIDs.contains(rule.id) {
                                        disabledRuleIDs.remove(rule.id)
                                    } else {
                                        disabledRuleIDs.insert(rule.id)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, DS.Spacing.xs)
            }
            .frame(maxHeight: 300)
        }
        .frame(width: 300)
    }
}

// MARK: - Row

private struct RuleDropdownRow: View {
    let rule: RuleFile
    let isActive: Bool
    let onToggle: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: rule.icon)
                    .font(.system(size: DS.IconSize.xs))
                    .foregroundStyle(isActive ? DS.Colors.accent : DS.Colors.textTertiary)
                    .frame(width: DS.IconSize.md)

                VStack(alignment: .leading, spacing: 1) {
                    Text(rule.name)
                        .font(DS.Font.bodySmall)
                        .fontWeight(.medium)
                        .foregroundStyle(isActive ? DS.Colors.textPrimary : DS.Colors.textTertiary)
                        .lineLimit(1)
                    Text(rule.trigger)
                        .font(DS.Font.monoSmall)
                        .foregroundStyle(DS.Colors.textTertiary)
                        .lineLimit(1)
                }

                Spacer()

                Toggle("", isOn: Binding(get: { isActive }, set: { _ in onToggle() }))
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .allowsHitTesting(false)
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.xs + 1)
            .background(isHovered ? DS.Colors.fillSecondary : DS.Colors.transparent)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plainPointer)
        .onHover { isHovered = $0 }
        .animation(DS.Animation.quick, value: isHovered)
    }
}
