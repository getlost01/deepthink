import SwiftUI

struct ContextItemView: View {
    let item: ContextItem

    var body: some View {
        VStack(spacing: 0) {
            // Metadata header
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: ContextService.iconForSource(item.source))
                    .font(.system(size: DS.IconSize.md, weight: .medium))
                    .foregroundStyle(ContextService.colorForSource(item.source))

                DSPill(text: item.source.capitalized, color: ContextService.colorForSource(item.source))

                Text(item.channel)
                    .font(DS.Font.body)
                    .foregroundStyle(DS.Colors.textSecondary)

                Spacer()

                Text(item.timestamp.relativeFormatted)
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Colors.textTertiary)

                DSToolbarButton(icon: "doc.on.doc", size: DS.IconSize.sm) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(item.content, forType: .string)
                }
                .help("Copy content")

                DSToolbarButton(icon: "folder", size: DS.IconSize.sm) {
                    NSWorkspace.shared.selectFile(item.filePath, inFileViewerRootedAtPath: "")
                }
                .help("Reveal in Finder")
            }
            .frame(height: DS.Layout.toolbarHeight)
            .padding(.horizontal, DS.Spacing.lg)
            .background(.bar)

            Divider()

            // Metadata fields if any
            if !item.metadata.isEmpty {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    ForEach(item.metadata.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                        HStack(spacing: DS.Spacing.sm) {
                            Text(key)
                                .font(DS.Font.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(DS.Colors.textTertiary)
                                .frame(width: 80, alignment: .trailing)

                            Text(value)
                                .font(DS.Font.caption)
                                .foregroundStyle(DS.Colors.textSecondary)

                            Spacer()
                        }
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.sm)
                .background(DS.Colors.fill)

                Divider()
            }

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    if let attributed = try? AttributedString(
                        markdown: item.content,
                        options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
                    ) {
                        Text(attributed)
                            .font(DS.Font.body)
                            .foregroundStyle(DS.Colors.textPrimary)
                            .textSelection(.enabled)
                    } else {
                        Text(item.content)
                            .font(DS.Font.body)
                            .foregroundStyle(DS.Colors.textPrimary)
                            .textSelection(.enabled)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(DS.Spacing.lg)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
