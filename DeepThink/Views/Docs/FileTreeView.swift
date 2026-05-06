import SwiftUI

struct FileNode: Identifiable, Hashable {
    let id: String
    let name: String
    let path: String
    let isDirectory: Bool
    var children: [FileNode]?

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: FileNode, rhs: FileNode) -> Bool { lhs.id == rhs.id }
}

struct FileTreeView: View {
    let rootPaths: [String]
    @Binding var selectedPath: String?
    @State private var roots: [FileNode] = []
    @State private var expandedPaths: Set<String> = []

    var body: some View {
        VStack(spacing: 0) {
            DSPageHeader(title: "Files") {
                Menu {
                    Button("Add Folder...") { pickFolder() }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: DS.IconSize.sm, weight: .medium))
                        .foregroundStyle(DS.Colors.textTertiary)
                }
                .menuStyle(.borderlessButton)
                .frame(width: 28)
            }

            Divider()

            if roots.isEmpty {
                VStack(spacing: DS.Spacing.lg) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(DS.Colors.textTertiary)
                    VStack(spacing: DS.Spacing.sm) {
                        Text("No folders open")
                            .font(DS.Font.body)
                            .foregroundStyle(DS.Colors.textSecondary)
                        Text("Add a folder to browse files")
                            .font(DS.Font.caption)
                            .foregroundStyle(DS.Colors.textTertiary)
                    }
                    Button("Open Folder") { pickFolder() }
                        .font(DS.Font.caption)
                        .buttonStyle(.dsSecondary)
                        .controlSize(.small)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(roots) { root in
                            FileNodeRow(
                                node: root,
                                depth: 0,
                                selectedPath: $selectedPath,
                                expandedPaths: $expandedPaths
                            )
                        }
                    }
                    .padding(.vertical, DS.Spacing.xs)
                }
            }
        }
        .onAppear { loadRoots() }
    }

    private func loadRoots() {
        roots = rootPaths.compactMap { buildTree(at: $0) }
    }

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            if let node = buildTree(at: url.path) {
                roots.append(node)
            }
        }
    }

    private func buildTree(at path: String) -> FileNode? {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: path, isDirectory: &isDir) else { return nil }

        let name = (path as NSString).lastPathComponent
        if isDir.boolValue {
            let contents = (try? fm.contentsOfDirectory(atPath: path)) ?? []
            let children = contents
                .filter { !$0.hasPrefix(".") }
                .sorted { lhs, rhs in
                    let lhsPath = (path as NSString).appendingPathComponent(lhs)
                    let rhsPath = (path as NSString).appendingPathComponent(rhs)
                    var lhsDir: ObjCBool = false
                    var rhsDir: ObjCBool = false
                    fm.fileExists(atPath: lhsPath, isDirectory: &lhsDir)
                    fm.fileExists(atPath: rhsPath, isDirectory: &rhsDir)
                    if lhsDir.boolValue != rhsDir.boolValue { return lhsDir.boolValue }
                    return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
                }
                .compactMap { buildTree(at: (path as NSString).appendingPathComponent($0)) }
            return FileNode(id: path, name: name, path: path, isDirectory: true, children: children)
        } else {
            return FileNode(id: path, name: name, path: path, isDirectory: false, children: nil)
        }
    }
}

// MARK: - Node Row

private struct FileNodeRow: View {
    let node: FileNode
    let depth: Int
    @Binding var selectedPath: String?
    @Binding var expandedPaths: Set<String>

    private var isExpanded: Bool { expandedPaths.contains(node.path) }
    private var isSelected: Bool { selectedPath == node.path }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                if node.isDirectory {
                    if isExpanded {
                        expandedPaths.remove(node.path)
                    } else {
                        expandedPaths.insert(node.path)
                    }
                } else {
                    selectedPath = node.path
                }
            } label: {
                HStack(spacing: DS.Spacing.xs) {
                    if node.isDirectory {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: DS.IconSize.xs, weight: .bold))
                            .foregroundStyle(DS.Colors.textTertiary)
                            .frame(width: 12)
                    } else {
                        Spacer().frame(width: 12)
                    }

                    Image(systemName: iconForFile(node))
                        .font(.system(size: DS.IconSize.sm))
                        .foregroundStyle(colorForFile(node))
                        .frame(width: 16)

                    Text(node.name)
                        .font(DS.Font.caption)
                        .lineLimit(1)
                        .foregroundStyle(isSelected ? DS.Colors.textPrimary : DS.Colors.textSecondary)
                }
                .padding(.leading, CGFloat(depth) * 16 + DS.Spacing.sm)
                .padding(.vertical, 3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(isSelected ? DS.Colors.accentFill : .clear)
            }
            .buttonStyle(.plainPointer)

            if node.isDirectory && isExpanded, let children = node.children {
                ForEach(children) { child in
                    FileNodeRow(
                        node: child,
                        depth: depth + 1,
                        selectedPath: $selectedPath,
                        expandedPaths: $expandedPaths
                    )
                }
            }
        }
    }

    private func iconForFile(_ node: FileNode) -> String {
        if node.isDirectory { return "folder.fill" }
        let ext = (node.name as NSString).pathExtension.lowercased()
        switch ext {
        case "md", "markdown": return "doc.richtext"
        case "swift": return "swift"
        case "ts", "tsx", "js", "jsx": return "chevron.left.forwardslash.chevron.right"
        case "py": return "chevron.left.forwardslash.chevron.right"
        case "json", "yaml", "yml", "toml": return "gearshape"
        case "html", "css": return "globe"
        case "pdf": return "doc.fill"
        case "png", "jpg", "jpeg", "gif", "svg": return "photo"
        case "txt", "log": return "doc.text"
        default: return "doc"
        }
    }

    private func colorForFile(_ node: FileNode) -> Color {
        if node.isDirectory { return DS.Colors.accent }
        let ext = (node.name as NSString).pathExtension.lowercased()
        switch ext {
        case "md", "markdown": return DS.Colors.info
        case "swift": return DS.Colors.amber
        case "ts", "tsx", "js", "jsx": return DS.Colors.gold
        case "py": return DS.Colors.success
        case "json", "yaml", "yml", "toml": return DS.Colors.slate
        case "pdf": return DS.Colors.danger
        default: return DS.Colors.textTertiary
        }
    }
}
