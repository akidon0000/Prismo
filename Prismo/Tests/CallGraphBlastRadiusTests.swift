import Testing
@testable import Prismo

@Suite("CallGraph blast radius")
struct CallGraphBlastRadiusTests {
    @Test("callers and callees are 1-hop neighbors")
    func neighbors() {
        let graph = CallGraph(
            nodes: [
                CallGraphNode(id: "a", symbolName: "A", kind: .type, filePath: "A.swift", line: 1, isChanged: true, order: 0),
                CallGraphNode(id: "b", symbolName: "B", kind: .type, filePath: "B.swift", line: 1, isChanged: true, order: 1),
                CallGraphNode(id: "c", symbolName: "C", kind: .type, filePath: "C.swift", line: 1, isChanged: true, order: 2),
            ],
            edges: [
                CallGraphEdge(fromID: "a", toID: "b"),
                CallGraphEdge(fromID: "b", toID: "c"),
            ]
        )
        #expect(graph.callers(of: "b").map(\.id) == ["a"])
        #expect(graph.callees(of: "b").map(\.id) == ["c"])
        #expect(graph.callers(of: "a").isEmpty)
        #expect(graph.callees(of: "c").isEmpty)
    }
}
