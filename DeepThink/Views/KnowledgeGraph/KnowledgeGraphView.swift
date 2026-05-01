import SwiftUI
import SwiftData

struct KnowledgeGraphView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Query private var notes: [Note]
    @State private var nodes: [NodePosition] = []
    @State private var edges: [(UUID, UUID)] = []
    @State private var selectedNodeID: UUID?
    @State private var draggedNode: UUID?
    @State private var scale: CGFloat = 1.0

    struct NodePosition: Identifiable {
        let id: UUID
        let title: String
        var position: CGPoint
        let connectionCount: Int
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(nsColor: .windowBackgroundColor)

                ForEach(edges, id: \.0) { source, target in
                    if let s = nodes.first(where: { $0.id == source }),
                       let t = nodes.first(where: { $0.id == target }) {
                        Path { path in
                            path.move(to: s.position)
                            path.addLine(to: t.position)
                        }
                        .stroke(.quaternary, lineWidth: 1)
                    }
                }

                ForEach(nodes) { node in
                    let isSelected = selectedNodeID == node.id
                    let radius = CGFloat(max(24, min(40, 20 + node.connectionCount * 4)))

                    ZStack {
                        Circle()
                            .fill(isSelected ? Color.accentColor : Color.accentColor.opacity(0.2))
                            .frame(width: radius, height: radius)
                            .shadow(color: isSelected ? .accentColor.opacity(0.4) : .clear, radius: 8)

                        Text(String(node.title.prefix(1)))
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(isSelected ? .white : .primary)
                    }
                    .position(node.position)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                if let idx = nodes.firstIndex(where: { $0.id == node.id }) {
                                    nodes[idx].position = value.location
                                }
                            }
                    )
                    .onTapGesture {
                        selectedNodeID = node.id
                    }
                    .onTapGesture(count: 2) {
                        appState.navigateToNote(node.id)
                    }

                    Text(node.title)
                        .font(.caption2)
                        .lineLimit(1)
                        .frame(width: 80)
                        .position(x: node.position.x, y: node.position.y + radius / 2 + 10)
                }
            }
            .scaleEffect(scale)
            .gesture(
                MagnifyGesture()
                    .onChanged { value in
                        scale = max(0.3, min(3.0, value.magnification))
                    }
            )
            .onAppear { layoutGraph(in: geo.size) }
            .onChange(of: notes.count) { layoutGraph(in: geo.size) }
        }
        .navigationTitle("Knowledge Graph")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button("Refresh") {
                    if let geo = NSApp.keyWindow?.contentView?.bounds.size {
                        layoutGraph(in: geo)
                    }
                }
            }
            if let nodeID = selectedNodeID, let note = notes.first(where: { $0.id == nodeID }) {
                ToolbarItem(placement: .automatic) {
                    Text(note.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func layoutGraph(in size: CGSize) {
        let graphNodes = BacklinkService.shared.buildGraph(notes: notes, context: modelContext)

        guard !graphNodes.isEmpty else {
            nodes = notes.enumerated().map { i, note in
                let angle = Double(i) / Double(max(notes.count, 1)) * 2 * .pi
                let radius = min(size.width, size.height) * 0.35
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                return NodePosition(
                    id: note.id,
                    title: note.title.isEmpty ? "Untitled" : note.title,
                    position: CGPoint(
                        x: center.x + cos(angle) * radius,
                        y: center.y + sin(angle) * radius
                    ),
                    connectionCount: 0
                )
            }
            edges = []
            return
        }

        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let radius = min(size.width, size.height) * 0.35

        nodes = graphNodes.enumerated().map { i, gNode in
            let angle = Double(i) / Double(graphNodes.count) * 2 * .pi
            return NodePosition(
                id: gNode.id,
                title: gNode.title.isEmpty ? "Untitled" : gNode.title,
                position: CGPoint(
                    x: center.x + cos(angle) * radius,
                    y: center.y + sin(angle) * radius
                ),
                connectionCount: gNode.connections.count
            )
        }

        var edgeSet: Set<String> = []
        var edgeList: [(UUID, UUID)] = []
        for gNode in graphNodes {
            for conn in gNode.connections {
                let key = [gNode.id.uuidString, conn.uuidString].sorted().joined()
                if edgeSet.insert(key).inserted {
                    edgeList.append((gNode.id, conn))
                }
            }
        }
        edges = edgeList
    }
}
