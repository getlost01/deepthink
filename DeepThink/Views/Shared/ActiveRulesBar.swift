import SwiftUI

struct ActiveRulesBar: View {
    let rules: [RuleFile]
    @Binding var disabledRuleIDs: Set<String>
    var onToggle: ((String) -> Void)?

    var body: some View {
        if !rules.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: DS.IconSize.xs))
                        .foregroundStyle(DS.Colors.textTertiary)

                    ForEach(rules) { rule in
                        let isActive = !disabledRuleIDs.contains(rule.id)
                        Button {
                            if let onToggle {
                                onToggle(rule.id)
                            } else {
                                if isActive {
                                    disabledRuleIDs.insert(rule.id)
                                } else {
                                    disabledRuleIDs.remove(rule.id)
                                }
                            }
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: rule.icon)
                                    .font(.system(size: DS.IconSize.micro))
                                Text(rule.name)
                                    .font(DS.Font.micro)
                            }
                            .padding(.horizontal, DS.Spacing.sm)
                            .padding(.vertical, DS.Spacing.xxs)
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
