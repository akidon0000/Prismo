import Testing
@testable import Prismo

@Suite("Jump navigation")
struct JumpNavigationTests {
    @Test("jumplist records and walks back/forward")
    func jumplist() {
        var list = SymbolJumpList()
        #expect(!list.canGoBack)
        #expect(!list.canGoForward)

        list.recordJump(from: "a", to: "b")
        #expect(list.canGoBack)
        #expect(!list.canGoForward)

        list.recordJump(from: "b", to: "c")
        #expect(list.back() == "b")
        #expect(list.canGoForward)
        #expect(list.forward() == "c")

        // mid-history jump discards forward
        _ = list.back()
        list.recordJump(from: "b", to: "d")
        #expect(list.forward() == nil)
        #expect(list.back() == "b")
    }

    @Test("callers and callees lists drive jump kinds")
    func neighborLists() {
        let graph = CallGraph(
            nodes: [
                CallGraphNode(id: "a", symbolName: "A", kind: .function, filePath: "A.swift", line: 1, isChanged: true, order: 0),
                CallGraphNode(id: "b", symbolName: "B", kind: .function, filePath: "B.swift", line: 2, isChanged: true, order: 1),
                CallGraphNode(id: "c", symbolName: "C", kind: .function, filePath: "C.swift", line: 3, isChanged: false, order: 2),
            ],
            edges: [
                CallGraphEdge(fromID: "a", toID: "b"),
                CallGraphEdge(fromID: "c", toID: "b"),
                CallGraphEdge(fromID: "b", toID: "c"),
            ]
        )
        let callers = graph.callers(of: "b")
        let callees = graph.callees(of: "b")
        #expect(Set(callers.map(\.id)) == ["a", "c"])
        #expect(callees.map(\.id) == ["c"])

        let picker = SymbolJumpPicker(kind: .callers, originID: "b", candidates: callers)
        #expect(picker.kind.title == "呼び出し元")
        #expect(picker.candidates.count == 2)
    }
}
