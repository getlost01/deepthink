import SwiftUI

struct StoryPointsBadge: View {
    let points: Int

    var body: some View {
        Text("\(points)")
            .font(DS.Font.small)
            .fontWeight(.semibold)
            .foregroundStyle(DS.Colors.accent)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(DS.Colors.accentFill, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
    }
}

struct TagChip: View {
    let tag: Tag

    var body: some View {
        Text(tag.name)
            .font(DS.Font.small)
            .fontWeight(.medium)
            .foregroundStyle(Color(hex: tag.color))
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xs)
            .background(Color(hex: tag.color).opacity(0.12), in: Capsule())
    }
}

struct StatusIndicator: View {
    let status: TaskStatus

    var body: some View {
        Image(systemName: status.icon)
            .font(.system(size: DS.IconSize.xs))
            .foregroundStyle(status.color)
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }

        return (positions, CGSize(width: maxX, height: y + rowHeight))
    }
}
