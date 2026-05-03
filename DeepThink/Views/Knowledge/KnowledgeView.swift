import SwiftUI

struct KnowledgeView: View {
    var body: some View {
        VStack(spacing: 0) {
            KnowledgeBrowserView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .dsPage()
    }
}
