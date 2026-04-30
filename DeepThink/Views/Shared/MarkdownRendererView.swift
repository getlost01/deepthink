import SwiftUI

struct MarkdownRendererView: View {
    let markdown: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let attributed = try? AttributedString(markdown: markdown, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
                    Text(attributed)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(markdown)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(DS.Spacing.lg)
        }
    }
}

struct MarkdownSplitEditor: View {
    @Binding var text: String
    @State private var showPreview = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Picker("", selection: $showPreview) {
                    Image(systemName: "pencil").tag(false)
                    Image(systemName: "eye").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(width: 80)
                .padding(.trailing, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.xs)
            }
            .background(.bar)

            Divider()

            if showPreview {
                MarkdownRendererView(markdown: text)
            } else {
                TextEditor(text: $text)
                    .font(.body.monospaced())
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.top, DS.Spacing.xs)
            }
        }
    }
}
