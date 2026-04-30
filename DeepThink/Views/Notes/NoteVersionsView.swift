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
        HSplitView {
            List(selection: Binding(
                get: { selectedVersion?.id },
                set: { id in selectedVersion = versions.first { $0.id == id } }
            )) {
                if versions.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.title2)
                            .foregroundStyle(.tertiary)
                        Text("No versions yet")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .listRowSeparator(.hidden)
                } else {
                    ForEach(versions) { version in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("v\(version.versionNumber)")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
                                Spacer()
                                Text(version.createdAt.relativeFormatted)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            Text(version.title.isEmpty ? "Untitled" : version.title)
                                .fontWeight(.medium)
                                .lineLimit(1)
                            Text("\(version.wordCount) words")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .tag(version.id)
                        .padding(.vertical, 2)
                    }
                }
            }
            .frame(minWidth: 200, idealWidth: 250, maxWidth: 300)

            if let version = selectedVersion {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("Version \(version.versionNumber)")
                            .font(.headline)
                        Text("— \(version.createdAt, style: .date)")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Restore This Version") {
                            VersioningService.shared.restore(note: note, from: version, context: modelContext)
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                    .padding(12)
                    .background(.bar)

                    Divider()

                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(version.title)
                                .font(.title2)
                                .fontWeight(.semibold)

                            Divider()

                            if let attributed = try? AttributedString(markdown: version.content, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
                                Text(attributed)
                                    .textSelection(.enabled)
                            } else {
                                Text(version.content)
                                    .font(.body.monospaced())
                                    .textSelection(.enabled)
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 36))
                        .foregroundStyle(.tertiary)
                    Text("Select a version to preview")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 700, minHeight: 400)
        .onAppear {
            versions = VersioningService.shared.versions(for: note.id, context: modelContext)
        }
    }
}
