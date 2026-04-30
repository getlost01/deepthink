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
            .padding(16)
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
                .padding(.trailing, 12)
                .padding(.vertical, 4)
            }
            .background(.bar)

            Divider()

            if showPreview {
                MarkdownRendererView(markdown: text)
            } else {
                TextEditor(text: $text)
                    .font(.body.monospaced())
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 12)
                    .padding(.top, 4)
            }
        }
    }
}
