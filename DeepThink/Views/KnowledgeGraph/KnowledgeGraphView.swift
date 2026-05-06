import SwiftUI
import SwiftData

// MARK: - Layout Mode

enum GraphLayoutMode: String, CaseIterable, Identifiable {
    case force = "Force"
    case circular = "Circular"
    case radial = "Radial"

    var id: String { rawValue }
}

// MARK: - Node Position

struct NodePosition: Identifiable {
    let id: UUID
    let title: String
    var position: CGPoint
    var velocity: CGPoint = .zero
    let connectionCount: Int
    var pinned: Bool = false
}

// MARK: - Knowledge Graph View

struct KnowledgeGraphView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Query private var notes: [Note]

    @State private var nodes: [NodePosition] = []
    @State private var edges: [(UUID, UUID)] = []
    @State private var selectedNodeID: UUID?
    @State private var hoveredNodeID: UUID?
    @State private var draggedNodeID: UUID?

    // Zoom & pan
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGPoint = .zero
    @State private var lastDragOffset: CGPoint = .zero
    @State private var lastScale: CGFloat = 1.0

    // Layout
    @State private var layoutMode: GraphLayoutMode = .force
    @State private var simulationTimer: Timer?
    @State private var simulationSteps: Int = 0
    @State private var canvasSize: CGSize = .zero

    // Force simulation constants
    private let repulsionStrength: CGFloat = 8000
    private let attractionStrength: CGFloat = 0.005
    private let centerGravity: CGFloat = 0.03
    private let damping: CGFloat = 0.85
    private let maxSteps: Int = 300
    private let idealEdgeLength: CGFloat = 150

    // Edge lookup for fast neighbor queries
    private var selectedNeighborIDs: Set<UUID> {
        guard let sel = selectedNodeID else { return [] }
        var neighbors = Set<UUID>()
        for (a, b) in edges {
            if a == sel { neighbors.insert(b) }
            if b == sel { neighbors.insert(a) }
        }
        return neighbors
    }

    // Connection count per edge for opacity
    private var edgeConnectionCounts: [String: Int] {
        var counts: [String: Int] = [:]
        for (a, b) in edges {
            let key = edgeKey(a, b)
            let countA = nodes.first(where: { $0.id == a })?.connectionCount ?? 0
            let countB = nodes.first(where: { $0.id == b })?.connectionCount ?? 0
            counts[key] = countA + countB
        }
        return counts
    }

    private var maxEdgeWeight: Int {
        max(edgeConnectionCounts.values.max() ?? 1, 1)
    }

    var body: some View {
        VStack(spacing: 0) {
            DSToolbarBar {
                Text("Knowledge Graph")
                    .font(DS.Font.heading)
                    .foregroundStyle(DS.Colors.textPrimary)

                Spacer()

                HStack(spacing: DS.Spacing.sm) {
                    ForEach(GraphLayoutMode.allCases) { mode in
                        Button {
                            layoutMode = mode
                        } label: {
                            Text(mode.rawValue)
                                .font(DS.Font.small)
                                .fontWeight(layoutMode == mode ? .semibold : .regular)
                                .foregroundStyle(layoutMode == mode ? DS.Colors.onAccent : DS.Colors.textSecondary)
                                .padding(.horizontal, DS.Spacing.sm)
                                .padding(.vertical, DS.Spacing.xs)
                                .background(layoutMode == mode ? DS.Colors.accent : DS.Colors.fill, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                        }
                        .buttonStyle(.plainPointer)
                    }
                }

                DSToolbarButton(icon: "arrow.counterclockwise", size: DS.IconSize.sm) {
                    withAnimation(DS.Animation.standard) {
                        scale = 1.0
                        offset = .zero
                    }
                }
                .help("Reset zoom & position")

                DSToolbarButton(icon: "arrow.triangle.2.circlepath", size: DS.IconSize.sm) {
                    buildAndLayout(in: canvasSize)
                }
                .help("Re-layout graph")

                if let nodeID = selectedNodeID, let note = notes.first(where: { $0.id == nodeID }) {
                    Text(note.title)
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Colors.accent)
                        .lineLimit(1)
                }
            }

            Divider()

        GeometryReader { geo in
            let transformedContent = ZStack {
                DS.Colors.surface

                // Edges
                Canvas { context, size in
                    let counts = edgeConnectionCounts
                    let maxW = CGFloat(maxEdgeWeight)
                    for (source, target) in edges {
                        guard let s = nodes.first(where: { $0.id == source }),
                              let t = nodes.first(where: { $0.id == target }) else { continue }

                        let key = edgeKey(source, target)
                        let weight = CGFloat(counts[key] ?? 1)
                        let normalizedWeight = weight / maxW

                        let isHighlighted = selectedNodeID != nil &&
                            (source == selectedNodeID || target == selectedNodeID)

                        let baseOpacity = 0.15 + 0.5 * normalizedWeight
                        let opacity = isHighlighted ? 0.9 : baseOpacity

                        // Quadratic bezier with control point offset perpendicular to the line
                        let mid = CGPoint(x: (s.position.x + t.position.x) / 2,
                                          y: (s.position.y + t.position.y) / 2)
                        let dx = t.position.x - s.position.x
                        let dy = t.position.y - s.position.y
                        let dist = sqrt(dx * dx + dy * dy)
                        let curvature: CGFloat = min(dist * 0.15, 30)
                        // Perpendicular offset
                        let nx = dist > 0 ? -dy / dist * curvature : 0
                        let ny = dist > 0 ? dx / dist * curvature : 0
                        let control = CGPoint(x: mid.x + nx, y: mid.y + ny)

                        var path = Path()
                        path.move(to: s.position)
                        path.addQuadCurve(to: t.position, control: control)

                        let lineWidth: CGFloat = isHighlighted ? 2 : 1
                        let color = isHighlighted
                            ? DS.Colors.accent.opacity(opacity)
                            : Color.primary.opacity(opacity)

                        context.stroke(path, with: .color(color), lineWidth: lineWidth)
                    }
                }

                // Nodes
                ForEach(nodes) { node in
                    nodeView(for: node)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)

            transformedContent
                .scaleEffect(scale, anchor: .center)
                .offset(x: offset.x, y: offset.y)
                .gesture(panGesture)
                .gesture(zoomGesture)
                .onAppear {
                    canvasSize = geo.size
                    buildAndLayout(in: geo.size)
                }
                .onChange(of: geo.size) { _, newSize in
                    canvasSize = newSize
                }
                .onChange(of: notes.count) {
                    buildAndLayout(in: canvasSize)
                }
                .onChange(of: layoutMode) {
                    applyLayout(in: canvasSize)
                }
        }
        }
    }

    // MARK: - Node View

    @ViewBuilder
    private func nodeView(for node: NodePosition) -> some View {
        let isSelected = selectedNodeID == node.id
        let isNeighbor = selectedNeighborIDs.contains(node.id)
        let isHovered = hoveredNodeID == node.id
        let isDimmed = selectedNodeID != nil && !isSelected && !isNeighbor
        let radius = CGFloat(max(24, min(48, 20 + node.connectionCount * 4)))

        let fillColor: Color = {
            if isSelected { return DS.Colors.accent }
            if isNeighbor { return DS.Colors.accent.opacity(0.5) }
            return DS.Colors.accent.opacity(0.2)
        }()

        ZStack {
            // Glow for selected
            if isSelected {
                Circle()
                    .fill(DS.Colors.accent.opacity(0.15))
                    .frame(width: radius + 16, height: radius + 16)
                    .blur(radius: 6)
            }

            Circle()
                .fill(fillColor)
                .frame(width: radius, height: radius)
                .shadow(color: isSelected ? DS.Colors.accent.opacity(0.4) : .clear, radius: 8)
                .overlay(
                    Circle()
                        .strokeBorder(isHovered ? DS.Colors.accent : Color.clear, lineWidth: 2)
                )

            Text(String(node.title.prefix(2)))
                .font(DS.Font.caption)
                .fontWeight(.bold)
                .foregroundStyle(isSelected ? DS.Colors.onAccent : DS.Colors.textPrimary)

            // Title label below
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: radius / 2 + 14)
                Text(isHovered ? node.title : String(node.title.prefix(12)) + (node.title.count > 12 ? "..." : ""))
                    .font(DS.Font.small)
                    .foregroundStyle(isDimmed ? DS.Colors.textTertiary : DS.Colors.textSecondary)
                    .lineLimit(isHovered ? 3 : 1)
                    .frame(width: isHovered ? 140 : 80)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.Spacing.xs)
                    .padding(.vertical, DS.Spacing.xxs)
                    .background(
                        isHovered
                            ? RoundedRectangle(cornerRadius: DS.Radius.sm)
                                .fill(DS.Colors.surfaceElevated.opacity(0.95))
                                .shadow(color: .black.opacity(0.1), radius: 4)
                            : nil
                    )
            }
        }
        .opacity(isDimmed ? 0.35 : 1.0)
        .position(node.position)
        .onHover { hovering in
            hoveredNodeID = hovering ? node.id : nil
        }
        .gesture(
            DragGesture(minimumDistance: 3)
                .onChanged { value in
                    draggedNodeID = node.id
                    if let idx = nodes.firstIndex(where: { $0.id == node.id }) {
                        // Convert drag location accounting for current scale and offset
                        let adjustedX = (value.location.x - offset.x) / scale + offset.x / scale
                        let adjustedY = (value.location.y - offset.y) / scale + offset.y / scale
                        // Simpler: just use the location directly in canvas coords
                        nodes[idx].position = value.location
                        nodes[idx].pinned = true
                        nodes[idx].velocity = .zero
                    }
                }
                .onEnded { _ in
                    if let idx = nodes.firstIndex(where: { $0.id == draggedNodeID }) {
                        nodes[idx].pinned = false
                    }
                    draggedNodeID = nil
                }
        )
        .simultaneousGesture(
            TapGesture(count: 2)
                .onEnded {
                    appState.navigateToNote(node.id)
                }
        )
        .simultaneousGesture(
            TapGesture(count: 1)
                .onEnded {
                    withAnimation(DS.Animation.quick) {
                        selectedNodeID = selectedNodeID == node.id ? nil : node.id
                    }
                }
        )
    }

    // MARK: - Gestures

    private var panGesture: some Gesture {
        DragGesture(minimumDistance: 5)
            .onChanged { value in
                guard draggedNodeID == nil else { return }
                offset = CGPoint(
                    x: lastDragOffset.x + value.translation.width,
                    y: lastDragOffset.y + value.translation.height
                )
            }
            .onEnded { _ in
                lastDragOffset = offset
            }
    }

    private var zoomGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let newScale = lastScale * value.magnification
                scale = max(0.2, min(4.0, newScale))
            }
            .onEnded { _ in
                lastScale = scale
            }
    }

    // MARK: - Graph Building

    private func buildAndLayout(in size: CGSize) {
        stopSimulation()

        let activeNotes = notes.filter {
            let title = $0.title.trimmingCharacters(in: .whitespaces)
            return !title.isEmpty && title != "Untitled Note" && !$0.content.isEmpty
        }
        let graphNodes = BacklinkService.shared.buildGraph(notes: activeNotes, context: modelContext)

        // Build edge list
        let activeIDs = Set(activeNotes.map(\.id))
        var edgeSet = Set<String>()
        var edgeList: [(UUID, UUID)] = []
        for gNode in graphNodes {
            for conn in gNode.connections where activeIDs.contains(conn) {
                let key = [gNode.id.uuidString, conn.uuidString].sorted().joined()
                if edgeSet.insert(key).inserted {
                    edgeList.append((gNode.id, conn))
                }
            }
        }
        edges = edgeList

        let connectionMap = Dictionary(uniqueKeysWithValues: graphNodes.map { ($0.id, $0.connections.count) })

        let center = CGPoint(x: size.width / 2, y: size.height / 2)

        var allNodes: [NodePosition] = []

        for note in activeNotes {
            let connCount = connectionMap[note.id] ?? 0
            let jitterRange: CGFloat = min(size.width, size.height) * 0.3
            let pos = CGPoint(
                x: center.x + CGFloat.random(in: -jitterRange...jitterRange),
                y: center.y + CGFloat.random(in: -jitterRange...jitterRange)
            )
            allNodes.append(NodePosition(
                id: note.id,
                title: note.title,
                position: pos,
                connectionCount: connCount
            ))
        }

        nodes = allNodes
        applyLayout(in: size)
    }

    private func applyLayout(in size: CGSize) {
        stopSimulation()

        switch layoutMode {
        case .circular:
            layoutCircular(in: size)
        case .radial:
            layoutRadial(in: size)
        case .force:
            layoutForceInitialPositions(in: size)
            startSimulation()
        }
    }

    // MARK: - Circular Layout

    private func layoutCircular(in size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let radius = min(size.width, size.height) * 0.35
        let count = max(nodes.count, 1)

        withAnimation(DS.Animation.standard) {
            for i in nodes.indices {
                let angle = Double(i) / Double(count) * 2 * .pi
                nodes[i].position = CGPoint(
                    x: center.x + cos(angle) * radius,
                    y: center.y + sin(angle) * radius
                )
                nodes[i].velocity = .zero
            }
        }
    }

    // MARK: - Radial Layout

    private func layoutRadial(in size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let sorted = nodes.sorted { $0.connectionCount > $1.connectionCount }
        let maxConn = sorted.first?.connectionCount ?? 1
        let ringSpacing = min(size.width, size.height) * 0.12

        // Group by connection "tier"
        var tiers: [[Int]] = [] // indices into sorted array
        var currentTier: [Int] = []
        var lastCount = -1
        for (i, node) in sorted.enumerated() {
            if node.connectionCount != lastCount && !currentTier.isEmpty {
                tiers.append(currentTier)
                currentTier = []
            }
            currentTier.append(i)
            lastCount = node.connectionCount
        }
        if !currentTier.isEmpty { tiers.append(currentTier) }

        // Map sorted index -> new position
        var positionMap: [UUID: CGPoint] = [:]

        for (tierIdx, tier) in tiers.enumerated() {
            let ringRadius = CGFloat(tierIdx) * ringSpacing
            let count = max(tier.count, 1)
            for (j, sortedIdx) in tier.enumerated() {
                let angle = Double(j) / Double(count) * 2 * .pi
                let node = sorted[sortedIdx]
                positionMap[node.id] = CGPoint(
                    x: center.x + cos(angle) * ringRadius,
                    y: center.y + sin(angle) * ringRadius
                )
            }
        }

        withAnimation(DS.Animation.standard) {
            for i in nodes.indices {
                if let pos = positionMap[nodes[i].id] {
                    nodes[i].position = pos
                    nodes[i].velocity = .zero
                }
            }
        }
    }

    // MARK: - Force-Directed Layout

    private func layoutForceInitialPositions(in size: CGSize) {
        // Scatter nodes randomly if they're all at the same point
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let spread = min(size.width, size.height) * 0.3

        for i in nodes.indices {
            let angle = Double(i) / Double(max(nodes.count, 1)) * 2 * .pi
            let r = spread * CGFloat.random(in: 0.3...1.0)
            nodes[i].position = CGPoint(
                x: center.x + cos(angle) * r,
                y: center.y + sin(angle) * r
            )
            nodes[i].velocity = .zero
        }
        simulationSteps = 0
    }

    private func startSimulation() {
        simulationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { _ in
            DispatchQueue.main.async {
                self.simulationStep()
            }
        }
    }

    private func stopSimulation() {
        simulationTimer?.invalidate()
        simulationTimer = nil
    }

    private func simulationStep() {
        guard simulationSteps < maxSteps else {
            stopSimulation()
            return
        }

        let n = nodes.count
        guard n > 0 else { return }

        let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)

        // Compute forces
        var forces = Array(repeating: CGPoint.zero, count: n)

        // Build index map
        var indexMap: [UUID: Int] = [:]
        for i in nodes.indices {
            indexMap[nodes[i].id] = i
        }

        // Repulsion: Coulomb-like between all pairs
        for i in 0..<n {
            for j in (i + 1)..<n {
                let dx = nodes[i].position.x - nodes[j].position.x
                let dy = nodes[i].position.y - nodes[j].position.y
                let distSq = max(dx * dx + dy * dy, 100) // avoid division by zero
                let dist = sqrt(distSq)
                let force = repulsionStrength / distSq
                let fx = force * dx / dist
                let fy = force * dy / dist
                forces[i].x += fx
                forces[i].y += fy
                forces[j].x -= fx
                forces[j].y -= fy
            }
        }

        // Attraction: spring-like along edges
        for (source, target) in edges {
            guard let si = indexMap[source], let ti = indexMap[target] else { continue }
            let dx = nodes[ti].position.x - nodes[si].position.x
            let dy = nodes[ti].position.y - nodes[si].position.y
            let dist = sqrt(dx * dx + dy * dy)
            let displacement = dist - idealEdgeLength
            let force = attractionStrength * displacement
            let fx = dist > 0 ? force * dx / dist : 0
            let fy = dist > 0 ? force * dy / dist : 0
            forces[si].x += fx
            forces[si].y += fy
            forces[ti].x -= fx
            forces[ti].y -= fy
        }

        // Center gravity
        for i in 0..<n {
            let dx = center.x - nodes[i].position.x
            let dy = center.y - nodes[i].position.y
            forces[i].x += dx * centerGravity
            forces[i].y += dy * centerGravity
        }

        // Apply forces with damping
        let currentDamping = damping * (1.0 - CGFloat(simulationSteps) / CGFloat(maxSteps) * 0.5)
        var totalMovement: CGFloat = 0

        for i in 0..<n {
            guard !nodes[i].pinned else { continue }

            nodes[i].velocity.x = (nodes[i].velocity.x + forces[i].x) * currentDamping
            nodes[i].velocity.y = (nodes[i].velocity.y + forces[i].y) * currentDamping

            // Clamp velocity
            let speed = sqrt(nodes[i].velocity.x * nodes[i].velocity.x + nodes[i].velocity.y * nodes[i].velocity.y)
            let maxSpeed: CGFloat = 20
            if speed > maxSpeed {
                nodes[i].velocity.x *= maxSpeed / speed
                nodes[i].velocity.y *= maxSpeed / speed
            }

            nodes[i].position.x += nodes[i].velocity.x
            nodes[i].position.y += nodes[i].velocity.y
            totalMovement += abs(nodes[i].velocity.x) + abs(nodes[i].velocity.y)
        }

        simulationSteps += 1

        // Stop early if stable
        if totalMovement < 0.5 {
            stopSimulation()
        }
    }

    // MARK: - Helpers

    private func edgeKey(_ a: UUID, _ b: UUID) -> String {
        [a.uuidString, b.uuidString].sorted().joined()
    }
}
