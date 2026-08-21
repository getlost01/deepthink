import Foundation

// A handoff is an explicit "here's where I left off" record one AI agent writes for
// the next. The registry is owned by the CLI/MCP (cli/src/tools/handoffs.ts) and
// stored as an id-keyed JSON object at ~/DeepThink/knowledge/handoffs.json. The app
// reads it to show the inbox, and can mark one claimed on the user's behalf.
struct Handoff: Codable, Identifiable, Hashable {
    let id: String
    let bucket: String
    let fromAgent: String
    var toAgent: String?
    let title: String
    let content: String
    var status: String
    let createdAt: String
    var claimedBy: String?
    var claimedAt: String?
    var notePath: String?

    var isOpen: Bool { status == "open" }

    var createdDate: Date? { Self.parseDate(createdAt) }
    var claimedDate: Date? { claimedAt.flatMap(Self.parseDate) }

    // The MCP writes ISO-8601 with fractional seconds (JS `toISOString`); fall back to
    // the plain form so either round-trips.
    static func parseDate(_ s: String) -> Date? {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = withFraction.date(from: s) { return d }
        return ISO8601DateFormatter().date(from: s)
    }
}

@Observable
final class HandoffService {
    static let shared = HandoffService()

    private(set) var handoffs: [Handoff] = []

    private var fileURL: URL {
        StorageService.shared.knowledgeURL.appendingPathComponent("handoffs.json")
    }

    private init() {}

    func reload() {
        guard let data = try? Data(contentsOf: fileURL),
              let map = try? JSONDecoder().decode([String: Handoff].self, from: data)
        else {
            handoffs = []
            return
        }
        // Newest first (createdAt is a sortable ISO-8601 string).
        handoffs = map.values.sorted { $0.createdAt > $1.createdAt }
    }

    var open: [Handoff] { handoffs.filter { $0.isOpen } }
    var claimed: [Handoff] { handoffs.filter { !$0.isOpen } }
    var openCount: Int { open.count }

    /// Mark a handoff claimed from the app, writing back to the shared registry so an
    /// agent's `recall` no longer surfaces it as open. Last-write-wins with the MCP;
    /// the write is atomic to avoid corrupting the file mid-write.
    @discardableResult
    func claim(_ id: String, by agent: String = "app") -> Bool {
        guard let data = try? Data(contentsOf: fileURL),
              var map = try? JSONDecoder().decode([String: Handoff].self, from: data),
              var h = map[id]
        else { return false }

        h.status = "claimed"
        h.claimedBy = agent
        h.claimedAt = ISO8601DateFormatter().string(from: Date())
        map[id] = h

        guard let out = try? JSONEncoder().encode(map) else { return false }
        do {
            try out.write(to: fileURL, options: .atomic)
        } catch {
            return false
        }
        reload()
        return true
    }
}
