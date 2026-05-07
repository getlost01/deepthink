import SwiftUI
import SwiftData

struct GeneralSettingsView: View {
    @AppStorage("autoArchiveTasks") private var autoArchiveTasks: Bool = true
    @AppStorage("archiveDaysThreshold") private var archiveDays: Int = 3
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.xl) {

                // MARK: Tasks
                DSSectionHeader(title: "Tasks")

                VStack(spacing: 0) {
                    settingToggleRow(
                        title: "Auto-archive completed tasks",
                        subtitle: "Automatically archive tasks marked as done after a set number of days.",
                        isOn: $autoArchiveTasks
                    )

                    if autoArchiveTasks {
                        Divider().padding(.leading, DS.Spacing.lg)

                        HStack(spacing: DS.Spacing.md) {
                            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                                Text("Archive after")
                                    .font(DS.Font.body)
                                    .foregroundStyle(DS.Colors.textPrimary)
                                Text("Days since completion before a task is archived.")
                                    .font(DS.Font.caption)
                                    .foregroundStyle(DS.Colors.textTertiary)
                            }
                            Spacer()
                            daysStepper(value: $archiveDays)
                        }
                        .padding(DS.Spacing.lg)

                        Divider().padding(.leading, DS.Spacing.lg)

                        HStack {
                            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                                Text("Run now")
                                    .font(DS.Font.body)
                                    .foregroundStyle(DS.Colors.textPrimary)
                                Text("Apply archive rules immediately without waiting for next launch.")
                                    .font(DS.Font.caption)
                                    .foregroundStyle(DS.Colors.textTertiary)
                            }
                            Spacer()
                            Button("Archive Now") {
                                ArchiveService.shared.triggerRun(container: modelContext.container)
                            }
                            .buttonStyle(.dsSecondary)
                        }
                        .padding(DS.Spacing.lg)
                    }

                }
                .background(DS.Colors.fill, in: RoundedRectangle(cornerRadius: DS.Radius.md))
                .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).strokeBorder(DS.Colors.border, lineWidth: 1))
            }
            .padding(DS.Spacing.xl)
        }
        .dsPage()
    }

    @ViewBuilder
    private func settingToggleRow(title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: DS.Spacing.md) {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(title)
                    .font(DS.Font.body)
                    .foregroundStyle(DS.Colors.textPrimary)
                Text(subtitle)
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Colors.textTertiary)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(DS.Spacing.lg)
    }

    @ViewBuilder
    private func daysStepper(value: Binding<Int>) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Button {
                if value.wrappedValue > 1 { value.wrappedValue -= 1 }
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: DS.IconSize.xs, weight: .semibold))
                    .frame(width: 26, height: 26)
                    .background(DS.Colors.fillSecondary, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                    .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm).strokeBorder(DS.Colors.border, lineWidth: 1))
            }
            .buttonStyle(.plainPointer)

            Text("\(value.wrappedValue) \(value.wrappedValue == 1 ? "day" : "days")")
                .font(DS.Font.body)
                .fontWeight(.semibold)
                .foregroundStyle(DS.Colors.textPrimary)
                .frame(minWidth: 64, alignment: .center)
                .monospacedDigit()

            Button {
                if value.wrappedValue < 90 { value.wrappedValue += 1 }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: DS.IconSize.xs, weight: .semibold))
                    .frame(width: 26, height: 26)
                    .background(DS.Colors.fillSecondary, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                    .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm).strokeBorder(DS.Colors.border, lineWidth: 1))
            }
            .buttonStyle(.plainPointer)
        }
    }
}
