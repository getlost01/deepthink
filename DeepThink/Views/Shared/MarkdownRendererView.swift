import SwiftUI

struct MarkdownRendererView: View {
    let markdown: String

    var body: some View {
        ScrollView {
            ChatMarkdownView(markdown: markdown)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(DS.Spacing.lg)
        }
        .dsPage()
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
            .background(DS.Colors.card)

            Divider()

            if showPreview {
                MarkdownRendererView(markdown: text)
            } else {
                TextEditor(text: $text)
                    .font(DS.Font.mono)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.top, DS.Spacing.xs)
                    .background(DS.Colors.page)
            }
        }
        .background(DS.Colors.page)
    }
}
