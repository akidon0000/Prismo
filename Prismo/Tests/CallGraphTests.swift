import Testing
@testable import Prismo

@Suite("CallGraph ordering")
struct CallGraphTests {
    @Test("orderedNodes follows call order, not file name")
    func orderedNodesFollowCallOrder() {
        let graph = CallGraph(
            nodes: [
                CallGraphNode(id: "b", symbolName: "B", kind: .function,
                              filePath: "a/B.swift", line: 1, isChanged: true, order: 1),
                CallGraphNode(id: "a", symbolName: "A", kind: .function,
                              filePath: "z/A.swift", line: 1, isChanged: true, order: 0),
                CallGraphNode(id: "c", symbolName: "C", kind: .function,
                              filePath: "m/C.swift", line: 1, isChanged: false, order: 2),
            ],
            edges: [
                CallGraphEdge(fromID: "a", toID: "b"),
                CallGraphEdge(fromID: "b", toID: "c"),
            ]
        )

        #expect(graph.orderedNodes.map(\.id) == ["a", "b", "c"])
    }

    @Test("fileColumns preserves first-seen call order")
    func fileColumnsPreserveCallOrder() {
        let graph = CallGraph(
            nodes: [
                CallGraphNode(id: "1", symbolName: "entry", kind: .function,
                              filePath: "z/Entry.swift", line: 1, isChanged: true, order: 0),
                CallGraphNode(id: "2", symbolName: "helper", kind: .function,
                              filePath: "a/Helper.swift", line: 1, isChanged: true, order: 1),
                CallGraphNode(id: "3", symbolName: "entryMore", kind: .function,
                              filePath: "z/Entry.swift", line: 20, isChanged: true, order: 2),
            ],
            edges: []
        )

        let columns = graph.fileColumns
        #expect(columns.map(\.filePath) == ["z/Entry.swift", "a/Helper.swift"])
        #expect(columns[0].nodes.map(\.id) == ["1", "3"])
        #expect(columns[1].nodes.map(\.id) == ["2"])
    }
}
