import Foundation
import CoreGraphics

/// 選択シンボルを中心にした 1-hop（必要なら 2-hop）の配置。
struct EgoGraphLayout: Sendable {
    enum Role: String, Sendable {
        case caller, focus, callee, neighbor
    }

    struct PlacedNode: Identifiable, Sendable {
        let id: String
        let node: CallGraphNode
        let role: Role
        let point: CGPoint
    }

    struct PlacedEdge: Identifiable, Sendable {
        let id: String
        let fromID: String
        let toID: String
        let from: CGPoint
        let to: CGPoint
        let involvesFocus: Bool
    }

    let nodes: [PlacedNode]
    let edges: [PlacedEdge]
    let focusID: String

    /// - Parameters:
    ///   - hops: 1 = 直接の呼び出し元/先のみ。2 = さらにその外側も薄く表示。
    static func make(
        graph: CallGraph,
        focusID: String,
        size: CGSize,
        hops: Int = 1
    ) -> EgoGraphLayout? {
        guard graph.node(id: focusID) != nil else { return nil }

        let callers = graph.callers(of: focusID)
        let callees = graph.callees(of: focusID)

        var outerCallers: [CallGraphNode] = []
        var outerCallees: [CallGraphNode] = []
        if hops >= 2 {
            var seen = Set(callers.map(\.id) + callees.map(\.id) + [focusID])
            for c in callers {
                for n in graph.callers(of: c.id) where !seen.contains(n.id) {
                    outerCallers.append(n)
                    seen.insert(n.id)
                }
            }
            for c in callees {
                for n in graph.callees(of: c.id) where !seen.contains(n.id) {
                    outerCallees.append(n)
                    seen.insert(n.id)
                }
            }
        }

        let padX: CGFloat = 28
        let padY: CGFloat = 28
        let usableW = max(size.width - padX * 2, 120)
        let usableH = max(size.height - padY * 2, 80)

        // 列: outerCallers | callers | focus | callees | outerCallees
        let columns: [(role: Role, nodes: [CallGraphNode])] = {
            var cols: [(Role, [CallGraphNode])] = []
            if !outerCallers.isEmpty { cols.append((.neighbor, outerCallers)) }
            cols.append((.caller, callers))
            if let focus = graph.node(id: focusID) {
                cols.append((.focus, [focus]))
            }
            cols.append((.callee, callees))
            if !outerCallees.isEmpty { cols.append((.neighbor, outerCallees)) }
            return cols
        }()

        let colCount = max(columns.count, 1)
        var placed: [String: PlacedNode] = [:]

        for (colIndex, column) in columns.enumerated() {
            let x: CGFloat
            if colCount == 1 {
                x = padX + usableW / 2
            } else {
                x = padX + usableW * CGFloat(colIndex) / CGFloat(colCount - 1)
            }
            let count = max(column.nodes.count, 1)
            for (rowIndex, node) in column.nodes.enumerated() {
                let y: CGFloat
                if column.nodes.count == 1 {
                    y = padY + usableH / 2
                } else {
                    y = padY + usableH * CGFloat(rowIndex) / CGFloat(count - 1)
                }
                // 同じノードが複数列に出ないよう focus / 直接隣人を優先
                if let existing = placed[node.id], existing.role == .focus { continue }
                if let existing = placed[node.id],
                   (existing.role == .caller || existing.role == .callee),
                   column.role == .neighbor {
                    continue
                }
                placed[node.id] = PlacedNode(id: node.id, node: node, role: column.role, point: CGPoint(x: x, y: y))
            }
        }

        let visibleIDs = Set(placed.keys)
        var edgeList: [PlacedEdge] = []
        for edge in graph.edges {
            guard visibleIDs.contains(edge.fromID), visibleIDs.contains(edge.toID),
                  let from = placed[edge.fromID], let to = placed[edge.toID] else { continue }
            let involves = edge.fromID == focusID || edge.toID == focusID
            edgeList.append(
                PlacedEdge(
                    id: "\(edge.fromID)->\(edge.toID)",
                    fromID: edge.fromID,
                    toID: edge.toID,
                    from: from.point,
                    to: to.point,
                    involvesFocus: involves
                )
            )
        }

        return EgoGraphLayout(
            nodes: Array(placed.values).sorted { $0.node.order < $1.node.order },
            edges: edgeList,
            focusID: focusID
        )
    }
}

extension CallGraph {
    /// 選択シンボル周りの Mermaid（呼び出し方向が分かる最小図）。
    func mermaidEgo(around focusID: String, hops: Int = 1) -> String {
        guard let focus = node(id: focusID) else { return "" }
        let callers = callers(of: focusID)
        let callees = callees(of: focusID)
        var ids = Set([focusID] + callers.map(\.id) + callees.map(\.id))
        if hops >= 2 {
            for c in callers { ids.formUnion(self.callers(of: c.id).map(\.id)) }
            for c in callees { ids.formUnion(self.callees(of: c.id).map(\.id)) }
        }

        var lines = ["```mermaid", "flowchart LR"]
        for id in ids {
            guard let n = node(id: id) else { continue }
            let label = "\(n.symbolName)".replacingOccurrences(of: "\"", with: "'")
            let shape = id == focusID ? "[[\(label)]]" : "[\(label)]"
            lines.append("  \(mermaidSafe(id))\(shape)")
        }
        for edge in edges where ids.contains(edge.fromID) && ids.contains(edge.toID) {
            lines.append("  \(mermaidSafe(edge.fromID)) --> \(mermaidSafe(edge.toID))")
        }
        lines.append("```")
        _ = focus
        return lines.joined(separator: "\n")
    }

    private func mermaidSafe(_ raw: String) -> String {
        "n" + String(raw.map { $0.isLetter || $0.isNumber ? $0 : "_" })
    }
}
