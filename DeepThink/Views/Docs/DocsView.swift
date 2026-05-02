import SwiftUI
import PDFKit

struct DocsView: View {
    @State private var selectedFilePath: String?
    @State private var rootPaths: [String] = []

    var body: some View {
        HStack(spacing: 0) {
            FileTreeView(rootPaths: rootPaths, selectedPath: $selectedFilePath)
                .frame(width: DS.Layout.panelWidth)

            Divider()

            if let path = selectedFilePath {
                DocRendererView(filePath: path)
                    .id(path)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                DSEmptyState(
                    icon: "doc.text.magnifyingglass",
                    title: "Browse Your Files",
                    subtitle: "Open a folder from the sidebar to browse and preview documents, code, and more"
                )
            }
        }
        .onAppear {
            if rootPaths.isEmpty {
                let docsPath = StorageService.shared.baseURL.appendingPathComponent("workspace").path
                let home = NSHomeDirectory()
                var paths: [String] = []
                if FileManager.default.fileExists(atPath: docsPath) {
                    paths.append(docsPath)
                }
                let commonDocs = (home as NSString).appendingPathComponent("Documents")
                if FileManager.default.fileExists(atPath: commonDocs) {
                    paths.append(commonDocs)
                }
                rootPaths = paths
            }
        }
    }
}

// MARK: - Document Renderer

struct DocRendererView: View {
    let filePath: String
    @State private var content: String?
    @State private var loadError: String?

    private var fileExtension: String {
        (filePath as NSString).pathExtension.lowercased()
    }

    private var fileName: String {
        (filePath as NSString).lastPathComponent
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: DS.Spacing.md) {
                Text(fileName)
                    .font(DS.Font.body)
                    .fontWeight(.medium)
                Spacer()

                DSToolbarButton(icon: "doc.on.doc", color: DS.Colors.textTertiary, size: DS.IconSize.sm) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(content ?? "", forType: .string)
                }
                .help("Copy contents")
                .disabled(content == nil)

                DSToolbarButton(icon: "arrow.up.right.square", color: DS.Colors.textTertiary, size: DS.IconSize.sm) {
                    NSWorkspace.shared.selectFile(filePath, inFileViewerRootedAtPath: "")
                }
                .help("Reveal in Finder")
            }
            .frame(height: DS.Layout.toolbarHeight)
            .padding(.horizontal, DS.Spacing.xl)
            .background(.bar)

            Divider()

            if let error = loadError {
                DSEmptyState(
                    icon: "exclamationmark.triangle",
                    title: "Cannot open file",
                    subtitle: error
                )
            } else if fileExtension == "pdf" {
                PDFDocView(filePath: filePath)
            } else if let content {
                switch fileExtension {
                case "md", "markdown":
                    MarkdownDocView(markdown: content)
                case "swift", "ts", "tsx", "js", "jsx", "py", "rb", "go", "rs",
                     "c", "cpp", "h", "m", "java", "kt", "cs", "sh", "zsh",
                     "bash", "html", "css", "scss", "sql", "yaml", "yml",
                     "toml", "xml", "json":
                    CodeDocView(code: content, language: languageForExt(fileExtension))
                default:
                    ScrollView {
                        Text(content)
                            .font(DS.Font.mono)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(DS.Spacing.lg)
                    }
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear { loadFile() }
    }

    private func loadFile() {
        guard fileExtension != "pdf" else { return }

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let text = try String(contentsOfFile: filePath, encoding: .utf8)
                DispatchQueue.main.async {
                    content = text
                }
            } catch {
                DispatchQueue.main.async {
                    loadError = error.localizedDescription
                }
            }
        }
    }

    private func languageForExt(_ ext: String) -> String {
        switch ext {
        case "ts", "tsx": return "typescript"
        case "js", "jsx": return "javascript"
        case "py": return "python"
        case "rb": return "ruby"
        case "go": return "go"
        case "rs": return "rust"
        case "c", "h": return "c"
        case "cpp": return "cpp"
        case "m": return "objectivec"
        case "java": return "java"
        case "kt": return "kotlin"
        case "cs": return "csharp"
        case "sh", "bash", "zsh": return "bash"
        case "html": return "html"
        case "css", "scss": return "css"
        case "sql": return "sql"
        case "yaml", "yml": return "yaml"
        case "toml": return "toml"
        case "xml": return "xml"
        case "json": return "json"
        case "swift": return "swift"
        default: return "plaintext"
        }
    }
}

// MARK: - PDF Viewer

struct PDFDocView: NSViewRepresentable {
    let filePath: String

    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        if let doc = PDFDocument(url: URL(fileURLWithPath: filePath)) {
            pdfView.document = doc
        }
        return pdfView
    }

    func updateNSView(_ nsView: PDFView, context: Context) {}
}
