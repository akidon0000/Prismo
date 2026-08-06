import Testing
import CoreGraphics
@testable import Prismo

@Suite("Ego graph layout")
struct CallGraphLayoutTests {
    private var sample: CallGraph {
        CallGraph(
            nodes: [
                CallGraphNode(id: "a", symbolName: "A", kind: .function, filePath: "A.swift", line: 1, isChanged: true, order: 0),
                CallGraphNode(id: "b", symbolName: "B", kind: .function, filePath: "B.swift", line: 2, isChanged: true, order: 1),
                CallGraphNode(id: "c", symbolName: "C", kind: .function, filePath: "C.swift", line: 3, isChanged: true, order: 2),
                CallGraphNode(id: "d", symbolName: "D", kind: .function, filePath: "D.swift", line: 4, isChanged: false, order: 3),
            ],
            edges: [
                CallGraphEdge(fromID: "a", toID: "b"),
                CallGraphEdge(fromID: "d", toID: "b"),
                CallGraphEdge(fromID: "b", toID: "c"),
            ]
        )
    }

    @Test("1-hop layout places callers left and callees right of focus")
    func oneHopColumns() {
        let layout = EgoGraphLayout.make(
            graph: sample,
            focusID: "b",
            size: CGSize(width: 400, height: 200),
            hops: 1
        )
        #expect(layout != nil)
        guard let layout else { return }

        let focus = layout.nodes.first { $0.role == .focus }
        let callers = layout.nodes.filter { $0.role == .caller }
        let callees = layout.nodes.filter { $0.role == .callee }
        #expect(focus?.id == "b")
        #expect(Set(callers.map(\.id)) == ["a", "d"])
        #expect(callees.map(\.id) == ["c"])

        guard let fx = focus?.point.x else { return }
        #expect(callers.allSatisfy { $0.point.x < fx })
        #expect(callees.allSatisfy { $0.point.x > fx })
        #expect(layout.edges.contains { $0.fromID == "a" && $0.toID == "b" && $0.involvesFocus })
    }

    @Test("mermaid ego marks focus and keeps direction")
    func mermaidEgo() {
        let md = sample.mermaidEgo(around: "b", hops: 1)
        #expect(md.contains("flowchart LR"))
        #expect(md.contains("[[B]]"))
        #expect(md.contains("-->"))
        #expect(md.contains("A") || md.contains("n"))
    }
}
