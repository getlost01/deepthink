import SwiftUI

struct ActiveRulesBar: View {
    let rules: [RuleFile]
    @Binding var disabledRuleIDs: Set<String>

    var body: some View {
        if !rules.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 8))
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
                                    .font(.system(size: 7))
                                Text(rule.name)
                                    .font(.system(size: 9, weight: .medium))
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                isActive ? DS.Colors.accentFill : DS.Colors.fill,
                                in: Capsule()
                            )
                            .foregroundStyle(isActive ? DS.Colors.accent : DS.Colors.textTertiary)
                            .opacity(isActive ? 1.0 : 0.5)
                        }
                        .buttonStyle(.plainPointer)
                        .help(isActive ? "Disable \(rule.name)" : "Enable \(rule.name)")
                    }
                }
            }
            .frame(maxWidth: 300)
        }
    }
}
