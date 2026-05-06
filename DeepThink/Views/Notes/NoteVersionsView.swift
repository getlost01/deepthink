import SwiftUI
import SwiftData

struct NoteVersionsView: View {
    let note: Note
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var versions: [NoteVersion] = []
    @State private var selectedVersion: NoteVersion?
    @State private var showDiff = false

    var body: some View {
        ResizableSplitView(minLeftWidth: 200, minRightWidth: 350) {
            List(selection: Binding(
                get: { selectedVersion?.id },
                set: { id in selectedVersion = versions.first { $0.id == id } }
            )) {
                if versions.isEmpty {
                    VStack(spacing: DS.Spacing.sm) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 24, weight: .light))
                            .foregroundStyle(DS.Colors.textTertiary)
                        Text("No versions yet")
                            .font(DS.Font.caption)
                            .foregroundStyle(DS.Colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .listRowSeparator(.hidden)
                } else {
                    ForEach(versions) { version in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("v\(version.versionNumber)")
                                    .font(DS.Font.small)
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, DS.Spacing.xxs)
                                    .background(DS.Colors.accentFill, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                                Spacer()
                                Text(version.createdAt.relativeFormatted)
                                    .font(DS.Font.small)
                                    .foregroundStyle(DS.Colors.textTertiary)
                            }
                            Text(version.title.isEmpty ? "Untitled" : version.title)
                                .font(DS.Font.body)
                                .fontWeight(.medium)
                                .lineLimit(1)
                            Text("\(version.wordCount) words")
                                .font(DS.Font.small)
                                .foregroundStyle(DS.Colors.textSecondary)
                        }
                        .tag(version.id)
                        .padding(.vertical, DS.Spacing.xxs)
                    }
                }
            }
            .listStyle(.plain)
            .background(DS.Colors.surface)
        } right: {
            if let version = selectedVersion {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("Version \(version.versionNumber)")
                            .font(DS.Font.heading)
                        Text("— \(version.createdAt, style: .date)")
                            .font(DS.Font.caption)
                            .foregroundStyle(DS.Colors.textSecondary)
                        Spacer()
                        Button("Restore This Version") {
                            VersioningService.shared.restore(note: note, from: version, context: modelContext)
                            dismiss()
                        }
                        .buttonStyle(.dsPrimary)
                        .controlSize(.small)
                    }
                    .padding(DS.Spacing.md)
                    .background(DS.Colors.surfaceElevated)

                    Divider()

                    ScrollView {
                        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                            Text(version.title)
                                .font(DS.Font.title)

                            Divider()

                            if let attributed = try? AttributedString(markdown: version.content, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
                                Text(attributed)
                                    .font(DS.Font.body)
                                    .textSelection(.enabled)
                            } else {
                                Text(version.content)
                                    .font(DS.Font.mono)
                                    .textSelection(.enabled)
                            }
                        }
                        .padding(DS.Spacing.lg)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            } else {
                DSEmptyState(
                    icon: "clock.arrow.circlepath",
                    title: "Select a Version",
                    subtitle: "Choose a version from the list to preview and restore."
                )
            }
        }
        .frame(minWidth: 700, minHeight: 400)
        .onAppear {
            versions = VersioningService.shared.versions(for: note.id, context: modelContext)
        }
    }
}
