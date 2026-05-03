import SwiftUI

struct SlashCommandMenu: View {
    let skills: [SkillFile]
    let filter: String
    @Binding var selectedIndex: Int
    let onSelect: (SkillFile) -> Void

    private var filtered: [SkillFile] {
        if filter.isEmpty { return skills }
        return skills.filter {
            $0.commandName.contains(filter.lowercased()) || $0.name.lowercased().contains(filter.lowercased())
        }
    }

    var body: some View {
        if filtered.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 0) {
                Text("SKILLS")
                    .font(DS.Font.small)
                    .fontWeight(.semibold)
                    .foregroundStyle(DS.Colors.textTertiary)
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.top, DS.Spacing.sm)
                    .padding(.bottom, DS.Spacing.xs)

                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(filtered.enumerated()), id: \.element.id) { index, skill in
                            Button {
                                onSelect(skill)
                            } label: {
                                HStack(spacing: DS.Spacing.sm) {
                                    Image(systemName: skill.icon)
                                        .font(.system(size: DS.IconSize.sm))
                                        .foregroundStyle(DS.Colors.accent)
                                        .frame(width: 20)

                                    VStack(alignment: .leading, spacing: 1) {
                                        Text("/" + skill.commandName)
                                            .font(DS.Font.body)
                                            .fontWeight(.medium)
                                            .foregroundStyle(DS.Colors.textPrimary)
                                        Text(skill.category)
                                            .font(DS.Font.small)
                                            .foregroundStyle(DS.Colors.textTertiary)
                                    }

                                    Spacer()
                                }
                                .padding(.horizontal, DS.Spacing.md)
                                .padding(.vertical, DS.Spacing.sm)
                                .background(
                                    index == selectedIndex
                                        ? DS.Colors.accentFill
                                        : Color.clear,
                                    in: RoundedRectangle(cornerRadius: DS.Radius.sm)
                                )
                            }
                            .buttonStyle(.plainPointer)
                        }
                    }
                    .padding(.horizontal, DS.Spacing.xs)
                }
                .frame(maxHeight: 240)
            }
            .padding(.bottom, DS.Spacing.sm)
            .onChange(of: filter) {
                selectedIndex = 0
            }
        }
    }

    var filteredCount: Int { filtered.count }

    func selectedSkill() -> SkillFile? {
        let f = filtered
        guard selectedIndex >= 0 && selectedIndex < f.count else { return f.first }
        return f[selectedIndex]
    }
}
