import SwiftData
import SwiftUI

// MARK: - EdgeKind

private enum EdgeKind: Equatable {
    case semantic
    case explicit
}

// MARK: - Node

private struct ContextNode: Identifiable {
    let id: String
    let title: String
    let source: String
    let bucket: String
    let tags: [String]
    var position: CGPoint
    var velocity: CGPoint = .zero
    var pinned: Bool = false
    var connectionCount: Int = 0
}

// MARK: - Edge

private struct ContextEdge: Identifiable {
    let id: String
    let fromID: String
    let toID: String
    let weight: Double
    var kind: EdgeKind = .semantic
}

// MARK: - Helpers

private func colorForSource(_ source: String) -> Color {
    let s = source.lowercased()
    if s.contains("slack") { return Color(hue: 0.57, saturation: 0.7, brightness: 0.9) }
    if s.contains("github") { return Color(hue: 0.08, saturation: 0.0, brightness: 0.4) }
    if s.contains("rss") { return Color(hue: 0.09, saturation: 0.75, brightness: 0.9) }
    if s.contains("web") { return Color(hue: 0.55, saturation: 0.6, brightness: 0.85) }
    if s.contains("file") { return Color(hue: 0.38, saturation: 0.55, brightness: 0.75) }
    return Color(hue: 0.72, saturation: 0.5, brightness: 0.85)
}

private func labelForSource(_ source: String) -> String {
    let s = source.lowercased()
    if s.contains("slack") { return "Slack" }
    if s.contains("github") { return "GitHub" }
    if s.contains("rss") { return "RSS" }
    if s.contains("web") { return "Web" }
    if s.contains("file") { return "File" }
    return "Manual"
}

// MARK: - View

struct ContextGraphView: View {
    @Query private var noteLinks: [NoteLink]
    @Query(filter: #Predicate<Note> { !$0.isArchived }) private var allNotes: [Note]

    @State private var nodes: [ContextNode] = []
    @State private var edges: [ContextEdge] = []
    @State private var showSemanticEdges = true
    @State private var showExplicitEdges = true

    @State private var selectedNodeID: String?
    @State private var hoveredNodeID: String?
    @State private var draggedNodeID: String?

    @State private var scale: CGFloat = 1.0
    @State private var offset: CGPoint = .zero
    @State private var lastDragOffset: CGPoint = .zero
    @State private var lastScale: CGFloat = 1.0

    @State private var simulationTimer: Timer?
    @State private var simulationSteps: Int = 0
    @State private var canvasSize: CGSize = .zero

    @State private var threshold: Double = 0.18
    @State private var query: String = ""
    @State private var queryScores: [String: Double] = [:]
    @State private var isBuilding = false
    @State private var showLegend = false
    @State private var showHint = false
    @State private var activeSourceFilter: String?
    @State private var queryDebounceTask: Task<Void, Never>?
    @State private var thresholdDebounceTask: Task<Void, Never>?
    @State private var isDraggingCanvas = false

    private let repulsionStrength: CGFloat = 9000
    private let attractionStrength: CGFloat = 0.006
    private let centerGravity: CGFloat = 0.025
    private let damping: CGFloat = 0.85
    private let maxSteps = 400
    private let idealEdgeLength: CGFloat = 160
    private let idealExplicitEdgeLength: CGFloat = 100
    private let explicitEdgeColor = Color(hue: 0.45, saturation: 0.65, brightness: 0.75).opacity(1)

    private var selectedNeighborIDs: Set<String> {
        guard let sel = selectedNodeID else { return [] }
        return Set(edges.flatMap { e -> [String] in
            if e.fromID == sel { return [e.toID] }
            if e.toID == sel { return [e.fromID] }
            return []
        })
    }

    private var selectedNode: ContextNode? {
        nodes.first(where: { $0.id == selectedNodeID })
    }

    private var uniqueSources: [String] {
        Array(Set(nodes.map { labelForSource($0.source) })).sorted()
    }

    private var displayNodes: [ContextNode] {
        guard let filter = activeSourceFilter else { return nodes }
        return nodes.filter { labelForSource($0.source) == filter }
    }

    private var displayEdges: [ContextEdge] {
        var result = edges
        if !showSemanticEdges { result = result.filter { $0.kind != .semantic } }
        if !showExplicitEdges { result = result.filter { $0.kind != .explicit } }
        guard activeSourceFilter != nil else { return result }
        let ids = Set(displayNodes.map(\.id))
        return result.filter { ids.contains($0.fromID) && ids.contains($0.toID) }
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar

            HStack(spacing: 0) {
                GeometryReader { geo in
                    ZStack {
                        DS.Colors.surface

                        if isBuilding {
                            VStack(spacing: DS.Spacing.md) {
                                ProgressView()
                                Text("Building similarity graph…")
                                    .font(DS.Font.caption)
                                    .foregroundStyle(DS.Colors.textSecondary)
                            }
                        } else if nodes.isEmpty {
                            VStack(spacing: DS.Spacing.md) {
                                Image(systemName: "point.3.connected.trianglepath.dotted")
                                    .font(.system(size: 40))
                                    .foregroundStyle(DS.Colors.textTertiary)
                                Text("No knowledge indexed yet")
                                    .font(DS.Font.body)
                                    .foregroundStyle(DS.Colors.textSecondary)
                                Text("Add entries to Knowledge to see connections")
                                    .font(DS.Font.caption)
                                    .foregroundStyle(DS.Colors.textTertiary)
                            }
                        } else {
                            graphCanvas(size: geo.size)
                            canvasControls
                        }
                    }
                    .clipped()
                    .onAppear {
                        canvasSize = geo.size
                        rebuild(in: geo.size)
                    }
                    .onChange(of: geo.size) { _, s in canvasSize = s }
                    .onChange(of: threshold) { _, _ in
                        thresholdDebounceTask?.cancel()
                        thresholdDebounceTask = Task {
                            try? await Task.sleep(for: .milliseconds(400))
                            guard !Task.isCancelled else { return }
                            await MainActor.run { rebuild(in: canvasSize) }
                        }
                    }
                    .onChange(of: query) { _, newVal in
                        queryDebounceTask?.cancel()
                        if newVal.trimmingCharacters(in: .whitespaces).isEmpty {
                            queryScores = [:]
                        } else {
                            queryDebounceTask = Task {
                                try? await Task.sleep(for: .milliseconds(300))
                                guard !Task.isCancelled else { return }
                                await MainActor.run { runQuery() }
                            }
                        }
                    }
                }
                .onKeyPress(.escape) {
                    withAnimation(DS.Animation.quick) { selectedNodeID = nil }
                    return .handled
                }

                if let node = selectedNode {
                    inspectorPanel(node: node)
                }
            }
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        VStack(spacing: 0) {
            DSToolbarBar {
                Text("Context Graph")
                    .font(DS.Font.heading)
                    .foregroundStyle(DS.Colors.textPrimary)

                Button { showLegend.toggle() } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: DS.IconSize.md))
                        .foregroundStyle(showLegend ? DS.Colors.accent : DS.Colors.textTertiary)
                }
                .buttonStyle(.plainPointer)
                .help("Legend")
                .popover(isPresented: $showLegend, arrowEdge: .bottom) { legendPopover }

                Button { showHint.toggle() } label: {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: DS.IconSize.md))
                        .foregroundStyle(showHint ? DS.Colors.accent : DS.Colors.textTertiary)
                }
                .buttonStyle(.plainPointer)
                .help("How does this work?")
                .popover(isPresented: $showHint, arrowEdge: .bottom) { hintPopover }

                Spacer()

                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: DS.IconSize.sm))
                        .foregroundStyle(query.isEmpty ? DS.Colors.textTertiary : DS.Colors.accent)
                    TextField("Search knowledge…", text: $query)
                        .textFieldStyle(.plain)
                        .font(DS.Font.body)
                        .frame(minWidth: 220, maxWidth: 360)
                    if !query.isEmpty {
                        Button {
                            query = ""
                            queryScores = [:]
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(DS.Colors.textTertiary)
                        }
                        .buttonStyle(.plainPointer)
                    }
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, 7)
                .background(DS.Colors.fill, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm).strokeBorder(
                    query.isEmpty ? DS.Colors.border : DS.Colors.accent,
                    lineWidth: query.isEmpty ? 1 : 1.5
                ))
                .animation(DS.Animation.quick, value: query.isEmpty)
            }

            HStack(spacing: DS.Spacing.sm) {
                Text("Rebuild graph:")
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Colors.textTertiary)

                Button { rebuild(in: canvasSize) } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 9, weight: .semibold))
                        .frame(width: 20, height: 20)
                        .background(DS.Colors.fill, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                        .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm).strokeBorder(DS.Colors.border, lineWidth: 1))
                }
                .buttonStyle(.plainPointer)
                .help("Rebuild graph")

                Text("Threshold:")
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Colors.textTertiary)

                Button { threshold = max(0.05, threshold - 0.01) } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 10, weight: .semibold))
                        .frame(width: 20, height: 20)
                        .background(DS.Colors.fill, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                        .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm).strokeBorder(DS.Colors.border, lineWidth: 1))
                }
                .buttonStyle(.plainPointer)

                Slider(value: $threshold, in: 0.05...0.5, step: 0.01)
                    .frame(width: 200)

                Button { threshold = min(0.5, threshold + 0.01) } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .semibold))
                        .frame(width: 20, height: 20)
                        .background(DS.Colors.fill, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                        .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm).strokeBorder(DS.Colors.border, lineWidth: 1))
                }
                .buttonStyle(.plainPointer)

                Text(String(format: "%.2f", threshold))
                    .font(DS.Font.caption.monospacedDigit())
                    .foregroundStyle(DS.Colors.textSecondary)
                    .frame(width: 36)

                if uniqueSources.count > 1 {
                    Divider().frame(height: 14)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: DS.Spacing.xs) {
                            ForEach(uniqueSources, id: \.self) { src in
                                let isActive = activeSourceFilter == src
                                Button {
                                    withAnimation(DS.Animation.quick) {
                                        activeSourceFilter = isActive ? nil : src
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(colorForSource(src))
                                            .frame(width: 6, height: 6)
                                        Text(src)
                                            .font(DS.Font.small)
                                            .foregroundStyle(isActive ? DS.Colors.onAccent : DS.Colors.textSecondary)
                                    }
                                    .padding(.horizontal, DS.Spacing.xs)
                                    .padding(.vertical, 3)
                                    .background(isActive ? DS.Colors.accent : DS.Colors.fill, in: Capsule())
                                    .overlay(Capsule().strokeBorder(
                                        isActive ? DS.Colors.accent : DS.Colors.border, lineWidth: 1
                                    ))
                                }
                                .buttonStyle(.plainPointer)
                            }
                        }
                    }
                }

                Spacer()

                // Edge type toggles
                Divider().frame(height: 14)
                let semanticCount = edges.count(where: { $0.kind == .semantic })
                let explicitCount = edges.count(where: { $0.kind == .explicit })
                Button {
                    withAnimation(DS.Animation.quick) { showSemanticEdges.toggle() }
                } label: {
                    HStack(spacing: 4) {
                        Rectangle().fill(DS.Colors.accent.opacity(0.7)).frame(width: 12, height: 2)
                        Text("Semantic (\(semanticCount))")
                            .font(DS.Font.small)
                            .foregroundStyle(showSemanticEdges ? DS.Colors.textPrimary : DS.Colors.textTertiary)
                    }
                    .padding(.horizontal, DS.Spacing.xs)
                    .padding(.vertical, 3)
                    .background(showSemanticEdges ? DS.Colors.fill : Color.clear, in: Capsule())
                    .overlay(Capsule().strokeBorder(DS.Colors.border, lineWidth: 1))
                    .opacity(showSemanticEdges ? 1 : 0.5)
                }
                .buttonStyle(.plainPointer)

                Button {
                    withAnimation(DS.Animation.quick) { showExplicitEdges.toggle() }
                } label: {
                    HStack(spacing: 4) {
                        Rectangle().fill(explicitEdgeColor).frame(width: 12, height: 2)
                        Text("Explicit (\(explicitCount))")
                            .font(DS.Font.small)
                            .foregroundStyle(showExplicitEdges ? DS.Colors.textPrimary : DS.Colors.textTertiary)
                    }
                    .padding(.horizontal, DS.Spacing.xs)
                    .padding(.vertical, 3)
                    .background(showExplicitEdges ? DS.Colors.fill : Color.clear, in: Capsule())
                    .overlay(Capsule().strokeBorder(DS.Colors.border, lineWidth: 1))
                    .opacity(showExplicitEdges ? 1 : 0.5)
                }
                .buttonStyle(.plainPointer)

                Spacer()

                if !queryScores.isEmpty {
                    Text("\(queryScores.count) match\(queryScores.count == 1 ? "" : "es")")
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Colors.accent)
                } else {
                    Text("\(nodes.count) nodes · \(semanticCount)S \(explicitCount)E edges")
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Colors.textTertiary)
                }

                Divider().frame(height: 14)

                Button { withAnimation(DS.Animation.quick) { scale = max(0.15, scale / 1.25); lastScale = scale } } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 9, weight: .semibold))
                        .frame(width: 20, height: 20)
                        .background(DS.Colors.fill, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                        .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm).strokeBorder(DS.Colors.border, lineWidth: 1))
                }
                .buttonStyle(.plainPointer)
                .help("Zoom out")

                Button { withAnimation(DS.Animation.quick) { scale = min(5.0, scale * 1.25); lastScale = scale } } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 9, weight: .semibold))
                        .frame(width: 20, height: 20)
                        .background(DS.Colors.fill, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                        .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm).strokeBorder(DS.Colors.border, lineWidth: 1))
                }
                .buttonStyle(.plainPointer)
                .help("Zoom in")

                Button { fitToScreen() } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 9, weight: .semibold))
                        .frame(width: 20, height: 20)
                        .background(DS.Colors.fill, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                        .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm).strokeBorder(DS.Colors.border, lineWidth: 1))
                }
                .buttonStyle(.plainPointer)
                .help("Fit to screen")

                Button {
                    withAnimation(DS.Animation.standard) {
                        scale = 1.0; offset = .zero
                        lastDragOffset = .zero; lastScale = 1.0
                    }
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 9, weight: .semibold))
                        .frame(width: 20, height: 20)
                        .background(DS.Colors.fill, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                        .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm).strokeBorder(DS.Colors.border, lineWidth: 1))
                }
                .buttonStyle(.plainPointer)
                .help("Reset view")
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .background(DS.Colors.surfaceElevated)

            Divider()
        }
    }

    // MARK: - Legend

    private var legendPopover: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("SOURCES")
                .font(DS.Font.micro)
                .foregroundStyle(DS.Colors.textTertiary)

            ForEach([("Slack", "slack"), ("GitHub", "github"), ("RSS", "rss"), ("Web", "web"), ("File", "file"), ("Manual", "")], id: \.0) { label, key in
                HStack(spacing: DS.Spacing.sm) {
                    Circle().fill(colorForSource(key)).frame(width: 10, height: 10)
                    Text(label).font(DS.Font.caption).foregroundStyle(DS.Colors.textSecondary)
                }
            }

            Divider()

            Text("EDGES")
                .font(DS.Font.micro)
                .foregroundStyle(DS.Colors.textTertiary)
            HStack(spacing: DS.Spacing.sm) {
                Rectangle()
                    .fill(LinearGradient(colors: [DS.Colors.accent.opacity(0.5), DS.Colors.accent], startPoint: .leading, endPoint: .trailing))
                    .frame(width: 22, height: 2)
                Text("Semantic (TF-IDF similarity)").font(DS.Font.caption).foregroundStyle(DS.Colors.textSecondary)
            }
            HStack(spacing: DS.Spacing.sm) {
                Rectangle().fill(explicitEdgeColor).frame(width: 22, height: 2)
                Text("Explicit ([[wiki]] links)").font(DS.Font.caption).foregroundStyle(DS.Colors.textSecondary)
            }

            Divider()

            Text("SIZE")
                .font(DS.Font.micro)
                .foregroundStyle(DS.Colors.textTertiary)
            Text("Larger node = more connections")
                .font(DS.Font.caption)
                .foregroundStyle(DS.Colors.textSecondary)

            Divider()

            Text("CONTROLS")
                .font(DS.Font.micro)
                .foregroundStyle(DS.Colors.textTertiary)
            VStack(alignment: .leading, spacing: 3) {
                HelpRow(key: "Click", action: "Select, inspect node")
                HelpRow(key: "Drag node", action: "Reposition")
                HelpRow(key: "Drag canvas", action: "Pan")
                HelpRow(key: "Pinch", action: "Zoom")
                HelpRow(key: "Esc", action: "Deselect")
            }
        }
        .padding(DS.Spacing.md)
        .frame(width: 210)
    }

    // MARK: - Hint Popover

    private var hintPopover: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text("How Context Graph works")
                    .font(DS.Font.heading)
                    .foregroundStyle(DS.Colors.textPrimary)
                Text("A visual map of how your knowledge entries relate to each other.")
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                HintStep(
                    number: "1",
                    title: "Indexing",
                    text: "Every knowledge entry is tokenized and scored using TF-IDF — common words are discounted, rare meaningful words get higher weight."
                )
                HintStep(
                    number: "2",
                    title: "Similarity",
                    text: "Each pair of entries is compared using cosine similarity on their TF-IDF vectors. Pairs above the threshold become connected by an edge."
                )
                HintStep(
                    number: "3",
                    title: "Threshold slider",
                    text: "Lower = more connections (looser matching). Higher = fewer, stronger connections only. Drag it to explore different cluster densities."
                )
                HintStep(
                    number: "4",
                    title: "Layout",
                    text: "Nodes are positioned by a force simulation — connected nodes pull together, all nodes push apart — until the graph settles."
                )
                HintStep(
                    number: "5",
                    title: "Search highlight",
                    text: "Type a query to run BM25 retrieval. Matching nodes light up with a relevance % badge. Non-matching nodes fade out."
                )
            }

            Divider()

            Text("Edge thickness = similarity strength. Node size = number of connections.")
                .font(DS.Font.small)
                .foregroundStyle(DS.Colors.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(DS.Spacing.md)
        .frame(width: 300)
    }

    // MARK: - Canvas Overlay Controls (unused — zoom controls moved to toolbar row)

    private var canvasControls: some View {
        EmptyView()
    }

    // MARK: - Canvas

    private func graphCanvas(size: CGSize) -> some View {
        ZStack {
            Canvas { context, sz in
                let spacing: CGFloat = 28
                let dot: CGFloat = 1
                let cols = Int(sz.width / spacing) + 2
                let rows = Int(sz.height / spacing) + 2
                for r in 0...rows {
                    for c in 0...cols {
                        context.fill(
                            Path(ellipseIn: CGRect(x: CGFloat(c) * spacing - dot, y: CGFloat(r) * spacing - dot, width: dot * 2, height: dot * 2)),
                            with: .color(Color.primary.opacity(0.05))
                        )
                    }
                }
            }
            .frame(width: size.width, height: size.height)

            Canvas { context, _ in
                let nodeMap = Dictionary(uniqueKeysWithValues: displayNodes.map { ($0.id, $0) })

                for edge in displayEdges {
                    guard let s = nodeMap[edge.fromID], let t = nodeMap[edge.toID] else { continue }

                    let isHighlighted = selectedNodeID != nil &&
                        (edge.fromID == selectedNodeID || edge.toID == selectedNodeID)
                    let isQueryHit = !queryScores.isEmpty &&
                        (queryScores[edge.fromID] != nil || queryScores[edge.toID] != nil)

                    let baseOpacity = 0.08 + edge.weight * 0.55
                    let opacity: Double = isHighlighted ? 1.0 : (isQueryHit ? 0.65 : baseOpacity)

                    let dx = t.position.x - s.position.x
                    let dy = t.position.y - s.position.y
                    let dist = max(sqrt(dx * dx + dy * dy), 1)
                    let mid = CGPoint(
                        x: (s.position.x + t.position.x) / 2,
                        y: (s.position.y + t.position.y) / 2
                    )
                    let curvature = min(dist * 0.08, 20.0)
                    let nx = -dy / dist * curvature
                    let ny = dx / dist * curvature
                    let control = CGPoint(x: mid.x + nx, y: mid.y + ny)

                    var path = Path()
                    path.move(to: s.position)
                    path.addQuadCurve(to: t.position, control: control)

                    if edge.kind == .explicit {
                        let lw: CGFloat = isHighlighted ? 3.0 : 2.0
                        let op: Double = isHighlighted ? 1.0 : (selectedNodeID != nil && !isHighlighted ? 0.25 : (isQueryHit ? 0.9 : 0.7))
                        if isHighlighted {
                            context.stroke(path, with: .color(explicitEdgeColor.opacity(0.22)), style: StrokeStyle(lineWidth: lw + 7, lineCap: .round))
                        }
                        context.stroke(path, with: .color(explicitEdgeColor.opacity(op)), style: StrokeStyle(lineWidth: lw, lineCap: .round))
                    } else {
                        let lineWidth = isHighlighted ? 2.5 : CGFloat(0.6 + edge.weight * 2.0)
                        let strokeStyle = StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                        if isHighlighted {
                            context.stroke(path, with: .color(DS.Colors.accent.opacity(0.18)), style: StrokeStyle(lineWidth: lineWidth + 6, lineCap: .round))
                            context.stroke(path, with: .color(DS.Colors.accent.opacity(opacity)), style: strokeStyle)
                        } else {
                            let colorA = colorForSource(s.source)
                            let colorB = colorForSource(t.source)
                            context.stroke(
                                path,
                                with: .linearGradient(
                                    Gradient(colors: [colorA.opacity(opacity), colorB.opacity(opacity)]),
                                    startPoint: s.position, endPoint: t.position
                                ),
                                style: strokeStyle
                            )
                        }
                    }
                }
            }
            .frame(width: size.width, height: size.height)

            ForEach(displayNodes) { node in
                nodeView(for: node)
            }
        }
        .scaleEffect(scale, anchor: .center)
        .offset(x: offset.x, y: offset.y)
        .gesture(panGesture)
        .gesture(zoomGesture)
        .frame(width: size.width, height: size.height)
        .clipped()
        .contentShape(Rectangle())
        .onHover { hovering in
            if hovering { NSCursor.openHand.push() } else { NSCursor.pop() }
        }
    }

    // MARK: - Node View

    @ViewBuilder
    private func nodeView(for node: ContextNode) -> some View {
        let isSelected = selectedNodeID == node.id
        let isNeighbor = selectedNeighborIDs.contains(node.id)
        let isHovered = hoveredNodeID == node.id
        let isDimmed = selectedNodeID != nil && !isSelected && !isNeighbor
        let hasQueryScore = !queryScores.isEmpty
        let qScore = queryScores[node.id] ?? 0
        let isQueryMatch = hasQueryScore && qScore > 0

        let radius = CGFloat(max(22, min(48, 18 + node.connectionCount * 5)))
        let nodeColor = colorForSource(node.source)
        let initial = String((node.title.first ?? "?").uppercased())

        let ringColor: Color = {
            if isSelected { return DS.Colors.accent }
            if isHovered { return DS.Colors.accent.opacity(0.85) }
            if isNeighbor { return DS.Colors.accent.opacity(0.5) }
            if isQueryMatch { return nodeColor }
            return nodeColor.opacity(0.45)
        }()

        let shadowColor: Color = isSelected
            ? DS.Colors.accent.opacity(0.45)
            : nodeColor.opacity(isDimmed ? 0 : 0.3)

        ZStack {
            // outer glow for selected / query match
            if isSelected {
                Circle()
                    .fill(DS.Colors.accent.opacity(0.15))
                    .frame(width: radius + 22, height: radius + 22)
                    .blur(radius: 10)
            } else if isQueryMatch {
                Circle()
                    .fill(nodeColor.opacity(0.18))
                    .frame(width: radius + 16, height: radius + 16)
                    .blur(radius: 8)
            }

            // body: radial gradient for depth
            Circle()
                .fill(
                    RadialGradient(
                        colors: isSelected
                            ? [DS.Colors.accent.opacity(0.85), DS.Colors.accent]
                            : (isNeighbor
                                ? [nodeColor.opacity(0.7), nodeColor.opacity(0.95)]
                                : [
                                    nodeColor.opacity(hasQueryScore && !isQueryMatch ? 0.15 : 0.65),
                                    nodeColor.opacity(hasQueryScore && !isQueryMatch ? 0.25 : 0.95)
                                ]),
                        center: UnitPoint(x: 0.35, y: 0.3),
                        startRadius: 0,
                        endRadius: radius * 0.85
                    )
                )
                .frame(width: radius, height: radius)
                .shadow(color: shadowColor, radius: isSelected ? 10 : 5, x: 0, y: 2)
                .overlay(
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color.white.opacity(0.18), Color.clear],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                        .frame(width: radius, height: radius)
                )
                .overlay(
                    Circle().strokeBorder(ringColor, lineWidth: isSelected || isHovered ? 2.5 : 1.5)
                )

            // initial letter
            Text(initial)
                .font(.system(size: max(11, radius * 0.38), weight: .bold, design: .rounded))
                .foregroundStyle(isSelected ? DS.Colors.onAccent : Color.white.opacity(0.9))

            // label below node — always visible, expand on hover
            VStack(spacing: 0) {
                Spacer().frame(height: radius / 2 + 8)
                Text(isHovered ? node.title : String(node.title.prefix(16)) + (node.title.count > 16 ? "…" : ""))
                    .font(DS.Font.small)
                    .foregroundStyle(isDimmed ? DS.Colors.textTertiary : DS.Colors.textSecondary)
                    .lineLimit(isHovered ? 3 : 1)
                    .frame(width: isHovered ? 160 : 100)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.Spacing.xs)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: DS.Radius.sm)
                            .fill(DS.Colors.surfaceElevated.opacity(isHovered ? 0.97 : 0.75))
                            .shadow(color: .black.opacity(isHovered ? 0.14 : 0.06), radius: isHovered ? 5 : 2)
                    )
                    .animation(DS.Animation.quick, value: isHovered)
            }

            // query score badge
            if isQueryMatch, let pct = queryScores[node.id] {
                VStack(spacing: 0) {
                    HStack {
                        Spacer()
                        Text(String(format: "%.0f%%", pct * 100))
                            .font(DS.Font.micro)
                            .foregroundStyle(Color.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(nodeColor, in: Capsule())
                            .offset(x: 6, y: -radius / 2)
                    }
                    Spacer()
                }
                .frame(width: radius + 12, height: radius + 12)
            }
        }
        .opacity(isDimmed ? 0.25 : 1.0)
        .animation(DS.Animation.quick, value: isSelected)
        .animation(DS.Animation.quick, value: isHovered)
        .position(node.position)
        .onHover { hovering in
            hoveredNodeID = hovering ? node.id : nil
            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
        .gesture(
            DragGesture(minimumDistance: 3)
                .onChanged { value in
                    draggedNodeID = node.id
                    if let idx = nodes.firstIndex(where: { $0.id == node.id }) {
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
            TapGesture().onEnded {
                withAnimation(DS.Animation.quick) {
                    selectedNodeID = selectedNodeID == node.id ? nil : node.id
                }
            }
        )
    }

    // MARK: - Inspector Panel

    private func inspectorPanel(node: ContextNode) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("DETAILS")
                    .font(DS.Font.micro)
                    .foregroundStyle(DS.Colors.textTertiary)
                Spacer()
                Button {
                    withAnimation(DS.Animation.quick) { selectedNodeID = nil }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(DS.Colors.textTertiary)
                        .frame(width: 18, height: 18)
                        .background(DS.Colors.fill, in: Circle())
                }
                .buttonStyle(.plainPointer)
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        Text(node.title)
                            .font(DS.Font.heading)
                            .foregroundStyle(DS.Colors.textPrimary)
                            .lineLimit(4)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: DS.Spacing.xs) {
                            Circle()
                                .fill(colorForSource(node.source))
                                .frame(width: 8, height: 8)
                            Text(node.source.isEmpty ? "manual" : node.source)
                                .font(DS.Font.caption)
                                .foregroundStyle(DS.Colors.textSecondary)
                        }

                        HStack(spacing: DS.Spacing.xs) {
                            Image(systemName: "point.3.connected.trianglepath.dotted")
                                .font(.system(size: 9))
                                .foregroundStyle(DS.Colors.textTertiary)
                            Text("\(node.connectionCount) connection\(node.connectionCount == 1 ? "" : "s")")
                                .font(DS.Font.caption)
                                .foregroundStyle(DS.Colors.textTertiary)
                        }
                    }

                    if !node.bucket.isEmpty {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("BUCKET")
                                .font(DS.Font.micro)
                                .foregroundStyle(DS.Colors.textTertiary)
                            Text(node.bucket)
                                .font(DS.Font.caption)
                                .foregroundStyle(DS.Colors.textSecondary)
                                .padding(.horizontal, DS.Spacing.xs)
                                .padding(.vertical, 3)
                                .background(DS.Colors.fill, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                        }
                    }

                    if !node.tags.isEmpty {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("TAGS")
                                .font(DS.Font.micro)
                                .foregroundStyle(DS.Colors.textTertiary)
                            FlowLayout(spacing: DS.Spacing.xs) {
                                ForEach(node.tags, id: \.self) { tag in
                                    Text(tag)
                                        .font(DS.Font.small)
                                        .foregroundStyle(DS.Colors.textSecondary)
                                        .padding(.horizontal, DS.Spacing.xs)
                                        .padding(.vertical, 2)
                                        .background(DS.Colors.fill, in: Capsule())
                                }
                            }
                        }
                    }

                    let neighbors = selectedNeighborIDs
                    if !neighbors.isEmpty {
                        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                            Text("CONNECTED (\(neighbors.count))")
                                .font(DS.Font.micro)
                                .foregroundStyle(DS.Colors.textTertiary)
                            ForEach(nodes.filter { neighbors.contains($0.id) }.sorted { lhs, rhs in
                                let lkind = edges.first(where: { ($0.fromID == node.id && $0.toID == lhs.id) || ($0.toID == node.id && $0.fromID == lhs.id) })?
                                    .kind ?? .semantic
                                let rkind = edges.first(where: { ($0.fromID == node.id && $0.toID == rhs.id) || ($0.toID == node.id && $0.fromID == rhs.id) })?
                                    .kind ?? .semantic
                                if lkind != rkind { return lkind == .explicit }
                                let lw = edges.first(where: { ($0.fromID == node.id && $0.toID == lhs.id) || ($0.toID == node.id && $0.fromID == lhs.id) })?
                                    .weight ?? 0
                                let rw = edges.first(where: { ($0.fromID == node.id && $0.toID == rhs.id) || ($0.toID == node.id && $0.fromID == rhs.id) })?
                                    .weight ?? 0
                                return lw > rw
                            }.prefix(10)) { n in
                                let connEdge = edges.first(where: {
                                    ($0.fromID == node.id && $0.toID == n.id) ||
                                        ($0.toID == node.id && $0.fromID == n.id)
                                })
                                let edgeWeight = connEdge?.weight ?? 0
                                let isExplicit = connEdge?.kind == .explicit
                                Button {
                                    withAnimation(DS.Animation.quick) { selectedNodeID = n.id }
                                } label: {
                                    HStack(spacing: DS.Spacing.xs) {
                                        Circle()
                                            .fill(colorForSource(n.source))
                                            .frame(width: 6, height: 6)
                                        Text(n.title)
                                            .font(DS.Font.caption)
                                            .foregroundStyle(DS.Colors.textSecondary)
                                            .lineLimit(1)
                                        Spacer()
                                        if isExplicit {
                                            Image(systemName: "link")
                                                .font(.system(size: 8, weight: .semibold))
                                                .foregroundStyle(explicitEdgeColor)
                                        } else {
                                            Text(String(format: "%.0f%%", edgeWeight * 100))
                                                .font(DS.Font.micro)
                                                .foregroundStyle(DS.Colors.textTertiary)
                                                .monospacedDigit()
                                        }
                                    }
                                    .padding(.vertical, 5)
                                    .padding(.horizontal, DS.Spacing.xs)
                                    .background(
                                        isExplicit ? explicitEdgeColor.opacity(0.08) : DS.Colors.fill,
                                        in: RoundedRectangle(cornerRadius: DS.Radius.sm)
                                    )
                                    .overlay(
                                        isExplicit ? RoundedRectangle(cornerRadius: DS.Radius.sm)
                                            .strokeBorder(explicitEdgeColor.opacity(0.3), lineWidth: 1) : nil
                                    )
                                }
                                .buttonStyle(.plainPointer)
                            }
                        }
                    }
                }
                .padding(DS.Spacing.md)
            }
        }
        .frame(width: 240)
        .background(DS.Colors.surface)
        .overlay(alignment: .leading) { Divider() }
    }

    // MARK: - Gestures

    private var panGesture: some Gesture {
        DragGesture(minimumDistance: 5)
            .onChanged { value in
                guard draggedNodeID == nil else { return }
                if !isDraggingCanvas {
                    isDraggingCanvas = true
                    NSCursor.closedHand.push()
                }
                offset = CGPoint(
                    x: lastDragOffset.x + value.translation.width,
                    y: lastDragOffset.y + value.translation.height
                )
            }
            .onEnded { _ in
                if isDraggingCanvas {
                    isDraggingCanvas = false
                    NSCursor.pop()
                }
                lastDragOffset = offset
            }
    }

    private var zoomGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in scale = max(0.15, min(5.0, lastScale * value.magnification)) }
            .onEnded { _ in lastScale = scale }
    }

    // MARK: - Build

    private func rebuild(in size: CGSize) {
        stopSimulation()
        isBuilding = true

        let knowledgeEntries = KnowledgeService.shared.entries
        let capturedLinks = noteLinks
        let capturedNotes = allNotes
        DispatchQueue.global(qos: .userInitiated).async {
            let engine = ContextEngine.shared
            guard !knowledgeEntries.isEmpty else {
                DispatchQueue.main.async { isBuilding = false; nodes = []; edges = [] }
                return
            }

            let rawEdges = engine.similarityEdges(threshold: threshold)
            let connectedIDs = Set(rawEdges.flatMap { [$0.0, $0.1] })
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let spread = min(size.width, size.height) * 0.35
            let connCounts = rawEdges.reduce(into: [String: Int]()) { acc, e in
                acc[e.0, default: 0] += 1
                acc[e.1, default: 0] += 1
            }

            var newNodes: [ContextNode] = []
            for (i, entry) in knowledgeEntries.enumerated() {
                guard connectedIDs.contains(entry.id) else { continue }
                let angle = Double(i) / Double(max(knowledgeEntries.count, 1)) * 2 * .pi
                let r = spread * CGFloat.random(in: 0.3...1.0)
                newNodes.append(ContextNode(
                    id: entry.id, title: entry.title, source: entry.source,
                    bucket: entry.bucket, tags: entry.tags,
                    position: CGPoint(x: center.x + cos(angle) * r, y: center.y + sin(angle) * r),
                    connectionCount: connCounts[entry.id] ?? 0
                ))
            }

            var newEdges = rawEdges.enumerated().map { i, e in
                ContextEdge(id: "\(i)", fromID: e.0, toID: e.1, weight: e.2)
            }

            // Build explicit edges from wiki [[links]] via NoteLink index
            let entryByTitle: [String: String] = Dictionary(
                knowledgeEntries.map { ($0.title.lowercased(), $0.id) },
                uniquingKeysWith: { first, _ in first }
            )
            let entryIDByNoteID: [UUID: String] = capturedNotes.reduce(into: [:]) { acc, note in
                if let id = entryByTitle[note.title.lowercased()] { acc[note.id] = id }
            }

            var seenExplicit = Set<String>()
            for link in capturedLinks {
                guard let fromID = entryIDByNoteID[link.sourceNoteID],
                      let toID = entryIDByNoteID[link.targetNoteID],
                      fromID != toID else { continue }
                let key = ([fromID, toID].sorted()).joined(separator: "|")
                guard seenExplicit.insert(key).inserted else { continue }
                let edgeID = "x_\(key)"
                newEdges.append(ContextEdge(id: edgeID, fromID: fromID, toID: toID, weight: 1.0, kind: .explicit))

                // Ensure both endpoint nodes exist even if below TF-IDF threshold
                for (nodeID, entryID) in [(fromID, fromID), (toID, toID)] {
                    if !newNodes.contains(where: { $0.id == nodeID }),
                       let entry = knowledgeEntries.first(where: { $0.id == entryID }),
                       let idx = knowledgeEntries.firstIndex(where: { $0.id == entryID })
                    {
                        let angle = Double(idx) / Double(max(knowledgeEntries.count, 1)) * 2 * .pi
                        let r = spread * CGFloat.random(in: 0.3...1.0)
                        newNodes.append(ContextNode(
                            id: entry.id, title: entry.title, source: entry.source,
                            bucket: entry.bucket, tags: entry.tags,
                            position: CGPoint(x: center.x + cos(angle) * r, y: center.y + sin(angle) * r),
                            connectionCount: 0
                        ))
                    }
                }
            }
            // Update connection counts for explicit edges
            for edge in newEdges where edge.kind == .explicit {
                if let i = newNodes.firstIndex(where: { $0.id == edge.fromID }) { newNodes[i].connectionCount += 1 }
                if let i = newNodes.firstIndex(where: { $0.id == edge.toID }) { newNodes[i].connectionCount += 1 }
            }

            DispatchQueue.main.async {
                nodes = newNodes; edges = newEdges
                isBuilding = false; simulationSteps = 0
                startSimulation()
            }
        }
    }

    // MARK: - Force Simulation

    private func startSimulation() {
        simulationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { _ in
            DispatchQueue.main.async { simulationStep() }
        }
    }

    private func stopSimulation() {
        simulationTimer?.invalidate()
        simulationTimer = nil
    }

    private func simulationStep() {
        guard simulationSteps < maxSteps, !nodes.isEmpty else { stopSimulation(); return }

        let n = nodes.count
        let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
        var forces = Array(repeating: CGPoint.zero, count: n)
        var indexMap: [String: Int] = [:]
        for i in nodes.indices {
            indexMap[nodes[i].id] = i
        }

        for i in 0..<n {
            for j in (i + 1)..<n {
                let dx = nodes[i].position.x - nodes[j].position.x
                let dy = nodes[i].position.y - nodes[j].position.y
                let distSq = max(dx * dx + dy * dy, 100)
                let dist = sqrt(distSq)
                let force = repulsionStrength / distSq
                let fx = force * dx / dist; let fy = force * dy / dist
                forces[i].x += fx; forces[i].y += fy
                forces[j].x -= fx; forces[j].y -= fy
            }
        }

        for edge in edges {
            guard let si = indexMap[edge.fromID], let ti = indexMap[edge.toID] else { continue }
            let dx = nodes[ti].position.x - nodes[si].position.x
            let dy = nodes[ti].position.y - nodes[si].position.y
            let dist = sqrt(dx * dx + dy * dy)
            let targetLen = edge.kind == .explicit ? idealExplicitEdgeLength : idealEdgeLength * CGFloat(1.0 - edge.weight * 0.4)
            let force = attractionStrength * (dist - targetLen)
            let fx = dist > 0 ? force * dx / dist : 0
            let fy = dist > 0 ? force * dy / dist : 0
            forces[si].x += fx; forces[si].y += fy
            forces[ti].x -= fx; forces[ti].y -= fy
        }

        for i in 0..<n {
            forces[i].x += (center.x - nodes[i].position.x) * centerGravity
            forces[i].y += (center.y - nodes[i].position.y) * centerGravity
        }

        let decay = damping * (1.0 - CGFloat(simulationSteps) / CGFloat(maxSteps) * 0.5)
        var totalMovement: CGFloat = 0

        for i in 0..<n {
            guard !nodes[i].pinned else { continue }
            nodes[i].velocity.x = (nodes[i].velocity.x + forces[i].x) * decay
            nodes[i].velocity.y = (nodes[i].velocity.y + forces[i].y) * decay
            let speed = sqrt(nodes[i].velocity.x * nodes[i].velocity.x + nodes[i].velocity.y * nodes[i].velocity.y)
            if speed > 20 {
                nodes[i].velocity.x *= 20 / speed
                nodes[i].velocity.y *= 20 / speed
            }
            nodes[i].position.x += nodes[i].velocity.x
            nodes[i].position.y += nodes[i].velocity.y
            totalMovement += abs(nodes[i].velocity.x) + abs(nodes[i].velocity.y)
        }

        simulationSteps += 1
        if totalMovement < 0.5 { stopSimulation() }
    }

    // MARK: - Fit to Screen

    private func fitToScreen() {
        guard !nodes.isEmpty, canvasSize != .zero else { return }
        let minX = nodes.map(\.position.x).min()!
        let maxX = nodes.map(\.position.x).max()!
        let minY = nodes.map(\.position.y).min()!
        let maxY = nodes.map(\.position.y).max()!
        let graphW = maxX - minX + 80
        let graphH = maxY - minY + 80
        let newScale = min(5.0, max(0.15, min(canvasSize.width / graphW, canvasSize.height / graphH) * 0.9))
        let centerX = (minX + maxX) / 2
        let centerY = (minY + maxY) / 2
        withAnimation(DS.Animation.standard) {
            scale = newScale; lastScale = newScale
            offset = CGPoint(
                x: (canvasSize.width / 2 - centerX) * newScale,
                y: (canvasSize.height / 2 - centerY) * newScale
            )
            lastDragOffset = offset
        }
    }

    // MARK: - Query

    private func runQuery() {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            queryScores = [:]; return
        }
        let bundle = ContextEngine.shared.retrieveContext(for: query, maxTokens: 99999)
        let maxScore = bundle.parts.map(\.relevanceScore).max() ?? 1
        queryScores = Dictionary(uniqueKeysWithValues:
            bundle.parts.map { ($0.id, $0.relevanceScore / maxScore) }
        )
    }
}

// MARK: - HintStep

private struct HintStep: View {
    let number: String
    let title: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: DS.Spacing.sm) {
            Text(number)
                .font(DS.Font.small)
                .fontWeight(.bold)
                .foregroundStyle(DS.Colors.onAccent)
                .frame(width: 18, height: 18)
                .background(DS.Colors.accent, in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DS.Font.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(DS.Colors.textPrimary)
                Text(text)
                    .font(DS.Font.small)
                    .foregroundStyle(DS.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - HelpRow

private struct HelpRow: View {
    let key: String
    let action: String

    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            Text(key)
                .font(DS.Font.small)
                .foregroundStyle(DS.Colors.textPrimary)
                .frame(width: 64, alignment: .leading)
            Text("→")
                .font(DS.Font.small)
                .foregroundStyle(DS.Colors.textTertiary)
            Text(action)
                .font(DS.Font.small)
                .foregroundStyle(DS.Colors.textSecondary)
        }
    }
}
