import SwiftUI

// Inbox of agent-to-agent handoffs. Open ones are waiting to be picked up; the user
// can mark one claimed. Data comes from HandoffService (reads the MCP-owned
// ~/DeepThink/knowledge/handoffs.json).
struct HandoffsView: View {
    @State private var service = HandoffService.shared
    @State private var filter: Filter = .open
    @State private var search = ""

    enum Filter: String, CaseIterable {
        case open = "Open"
        case claimed = "Claimed"
        case all = "All"
    }

    private var filtered: [Handoff] {
        let base: [Handoff]
        switch filter {
        case .open: base = service.open
        case .claimed: base = service.claimed
        case .all: base = service.handoffs
        }
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return base }
        return base.filter {
            $0.title.lowercased().contains(q) || $0.content.lowercased().contains(q)
                || $0.fromAgent.lowercased().contains(q) || $0.bucket.lowercased().contains(q)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            filterBar
            Divider()
            content
        }
        .onAppear { service.reload() }
    }

    private var filterBar: some View {
        HStack(spacing: DS.Spacing.sm) {
            ForEach(Filter.allCases, id: \.self) { f in
                DSFilterChip(
                    label: f.rawValue,
                    count: count(for: f),
                    isSelected: filter == f,
                    action: { filter = f }
                )
            }
            Spacer()
            DSSearchField(text: $search, placeholder: "Search handoffs")
                .frame(maxWidth: 240)
            Button(action: { service.reload() }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: DS.IconSize.md, weight: .medium))
                    .foregroundStyle(DS.Colors.textSecondary)
            }
            .buttonStyle(.plainPointer)
            .help("Refresh")
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
    }

    private func count(for f: Filter) -> Int? {
        switch f {
        case .open: return service.open.count
        case .claimed: return service.claimed.count
        case .all: return service.handoffs.count
        }
    }

    @ViewBuilder
    private var content: some View {
        ScrollView {
            if filtered.isEmpty {
                emptyState
                    .frame(maxWidth: .infinity, minHeight: 360)
            } else {
                LazyVStack(spacing: DS.Spacing.md) {
                    ForEach(filtered) { handoff in
                        HandoffCard(handoff: handoff) { service.claim(handoff.id) }
                    }
                }
                .padding(DS.Spacing.lg)
            }
        }
        .dsPage()
    }

    @ViewBuilder
    private var emptyState: some View {
        switch filter {
        case .open:
            DSEmptyState(
                icon: "tray",
                title: "No open handoffs",
                subtitle: "You're all caught up — nothing is waiting to be picked up."
            )
        case .claimed:
            DSEmptyState(icon: "checkmark.circle", title: "No claimed handoffs yet")
        case .all:
            DSEmptyState(
                icon: "tray.and.arrow.down",
                title: "No handoffs",
                subtitle: "When one AI agent hands off to another, it shows up here.",
                hint: "Agents create these with knowledge_session {action:'handoff'}."
            )
        }
    }
}

// MARK: - Card

private struct HandoffCard: View {
    let handoff: Handoff
    let onClaim: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(alignment: .top, spacing: DS.Spacing.sm) {
                Image(systemName: "tray.and.arrow.down")
                    .font(.system(size: DS.IconSize.md, weight: .medium))
                    .foregroundStyle(statusColor)
                Text(handoff.title)
                    .font(DS.Font.heading)
                    .foregroundStyle(DS.Colors.textPrimary)
                    .lineLimit(2)
                Spacer(minLength: DS.Spacing.sm)
                DSPill(text: handoff.isOpen ? "Open" : "Claimed", color: statusColor)
            }

            HStack(spacing: DS.Spacing.xs2) {
                DSPill(text: handoff.fromAgent, color: DS.Colors.info)
                Image(systemName: "arrow.right")
                    .font(.system(size: DS.IconSize.xs, weight: .semibold))
                    .foregroundStyle(DS.Colors.textTertiary)
                DSPill(text: handoff.toAgent ?? "anyone", color: DS.Colors.accent)
                DSPill(text: handoff.bucket, color: DS.Colors.slate)
                Spacer(minLength: DS.Spacing.sm)
                if let when = relativeCreated {
                    Text(when)
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Colors.textTertiary)
                }
            }

            Text(handoff.content)
                .font(DS.Font.bodySmall)
                .foregroundStyle(DS.Colors.textSecondary)
                .lineLimit(6)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                if !handoff.isOpen, let by = handoff.claimedBy {
                    Text("Claimed by \(by)\(relativeClaimed.map { " · \($0)" } ?? "")")
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Colors.success)
                }
                Spacer()
                if handoff.isOpen {
                    Button("Mark claimed", action: onClaim)
                        .buttonStyle(.dsSecondary)
                }
            }
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.fill)
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg)
                .stroke(handoff.isOpen ? DS.Colors.badgeBorder(statusColor) : DS.Colors.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
    }

    private var statusColor: Color {
        handoff.isOpen ? DS.Colors.warning : DS.Colors.success
    }

    private var relativeCreated: String? {
        handoff.createdDate.map { Self.relative.localizedString(for: $0, relativeTo: Date()) }
    }

    private var relativeClaimed: String? {
        handoff.claimedDate.map { Self.relative.localizedString(for: $0, relativeTo: Date()) }
    }

    private static let relative: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()
}
