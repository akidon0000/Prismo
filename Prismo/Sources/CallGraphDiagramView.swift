import SwiftUI

/// 選択シンボルを中心に、呼び出し元 → 先を矢印で結ぶ図。
struct CallGraphDiagramView: View {
    let graph: CallGraph
    let focusID: String
    let hops: Int
    let onSelect: (CallGraphNode) -> Void

    private let nodeSize = CGSize(width: 120, height: 44)

    var body: some View {
        GeometryReader { geo in
            let layout = EgoGraphLayout.make(
                graph: graph,
                focusID: focusID,
                size: geo.size,
                hops: hops
            )

            ZStack {
                Theme.paneBackground

                if let layout {
                    Canvas { context, _ in
                        for edge in layout.edges {
                            drawEdge(edge, in: &context)
                        }
                    }
                    .allowsHitTesting(false)

                    ForEach(layout.nodes) { placed in
                        nodeBadge(placed)
                            .position(placed.point)
                    }

                    // 凡例
                    VStack(alignment: .leading, spacing: 2) {
                        legend(color: Theme.warning, text: "callers ← 呼ばれる")
                        legend(color: Theme.accent, text: "focus")
                        legend(color: Theme.addition, text: "callees → 呼ぶ")
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                } else {
                    Text("グラフを描けません")
                        .font(Theme.monoCaption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }

    private func legend(color: Color, text: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(text)
                .font(Theme.monoCaption2)
                .foregroundStyle(.secondary)
        }
    }

    private func nodeBadge(_ placed: EgoGraphLayout.PlacedNode) -> some View {
        let selected = placed.role == .focus
        return Button {
            onSelect(placed.node)
        } label: {
            VStack(spacing: 2) {
                Text(placed.node.kind.label)
                    .font(Theme.monoCaption2)
                    .foregroundStyle(.secondary)
                Text(placed.node.symbolName)
                    .font(Theme.monoCaption.weight(selected ? .bold : .medium))
                    .lineLimit(1)
                Text((placed.node.filePath as NSString).lastPathComponent)
                    .font(Theme.monoCaption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(width: nodeSize.width, height: nodeSize.height)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(fill(for: placed.role))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(stroke(for: placed.role), lineWidth: selected ? 2 : 1)
            )
            .opacity(placed.role == .neighbor ? 0.55 : 1)
        }
        .buttonStyle(.plain)
        .help("\(placed.node.symbolName) · \(placed.node.filePath):\(placed.node.line)")
    }

    private func fill(for role: EgoGraphLayout.Role) -> Color {
        switch role {
        case .focus: return Theme.accent.opacity(0.22)
        case .caller: return Theme.warning.opacity(0.14)
        case .callee: return Theme.addition.opacity(0.14)
        case .neighbor: return Color.primary.opacity(0.05)
        }
    }

    private func stroke(for role: EgoGraphLayout.Role) -> Color {
        switch role {
        case .focus: return Theme.accent
        case .caller: return Theme.warning.opacity(0.8)
        case .callee: return Theme.addition.opacity(0.8)
        case .neighbor: return Color.primary.opacity(0.2)
        }
    }

    private func drawEdge(_ edge: EgoGraphLayout.PlacedEdge, in context: inout GraphicsContext) {
        // ノード枠の端まで矢印を短くする
        let inset = nodeSize.width / 2 + 4
        let dx = edge.to.x - edge.from.x
        let dy = edge.to.y - edge.from.y
        let len = max(hypot(dx, dy), 1)
        let ux = dx / len
        let uy = dy / len
        let start = CGPoint(x: edge.from.x + ux * inset, y: edge.from.y + uy * inset)
        let end = CGPoint(x: edge.to.x - ux * inset, y: edge.to.y - uy * inset)

        var path = Path()
        path.move(to: start)
        // 軽い曲線で重なりを避ける
        let mid = CGPoint(
            x: (start.x + end.x) / 2,
            y: (start.y + end.y) / 2 - (edge.involvesFocus ? 0 : 12)
        )
        path.addQuadCurve(to: end, control: mid)

        context.stroke(
            path,
            with: .color(edge.involvesFocus ? Theme.accent.opacity(0.85) : Color.secondary.opacity(0.35)),
            style: StrokeStyle(lineWidth: edge.involvesFocus ? 1.6 : 1, lineCap: .round)
        )

        // 矢印頭
        let angle = atan2(end.y - mid.y, end.x - mid.x)
        let arrowLen: CGFloat = 8
        let a1 = angle + .pi * 0.8
        let a2 = angle - .pi * 0.8
        var arrow = Path()
        arrow.move(to: end)
        arrow.addLine(to: CGPoint(x: end.x + cos(a1) * arrowLen, y: end.y + sin(a1) * arrowLen))
        arrow.move(to: end)
        arrow.addLine(to: CGPoint(x: end.x + cos(a2) * arrowLen, y: end.y + sin(a2) * arrowLen))
        context.stroke(
            arrow,
            with: .color(edge.involvesFocus ? Theme.accent : Color.secondary.opacity(0.45)),
            style: StrokeStyle(lineWidth: 1.4, lineCap: .round)
        )
    }
}
