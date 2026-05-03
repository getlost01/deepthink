import SwiftUI

struct ActiveRulesBar: View {
    let rules: [RuleFile]
    @Binding var disabledRuleIDs: Set<String>

    var body: some View {
        if !rules.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(DS.Colors.textTertiary)

                    ForEach(rules) { rule in
                        let isActive = !disabledRuleIDs.contains(rule.id)
                        Button {
                            if isActive {
                                disabledRuleIDs.insert(rule.id)
                            } else {
                                disabledRuleIDs.remove(rule.id)
                            }
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: rule.icon)
                                    .font(.system(size: 8))
                                Text(rule.name)
                                    .font(DS.Font.small)
                                    .fontWeight(.medium)
                            }
                            .padding(.horizontal, DS.Spacing.sm)
                            .padding(.vertical, 3)
                            .background(
                                isActive ? DS.Colors.accentFill : DS.Colors.fill,
                                in: Capsule()
                            )
                            .foregroundStyle(isActive ? DS.Colors.accent : DS.Colors.textTertiary)
                            .opacity(isActive ? 1.0 : 0.5)
                        }
                        .buttonStyle(.plain)
                        .help(isActive ? "Click to disable \(rule.name)" : "Click to enable \(rule.name)")
                    }
                }
            }
        }
    }
}
