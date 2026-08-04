import Testing
@testable import Prismo

@Suite("ImportCallGraphBuilder")
struct ImportCallGraphBuilderTests {
    @Test("Swift imports order callers before callees")
    func swiftImportOrdering() {
        let files = [
            GitHubPullFile(
                filename: "Sources/App/AppFeature.swift",
                status: "modified",
                additions: 3,
                deletions: 0,
                changes: 3,
                patch: """
                @@ -1,3 +1,6 @@
                 import Foundation
                +import InboxKit
                +struct AppFeature {
                +    func start() {}
                +}
                """
            ),
            GitHubPullFile(
                filename: "Sources/Inbox/InboxStore.swift",
                status: "modified",
                additions: 4,
                deletions: 0,
                changes: 4,
                patch: """
                @@ -1,2 +1,6 @@
                 import Foundation
                +public final class InboxStore {
                +    public func refresh() {}
                +}
                """
            ),
        ]

        let graph = ImportCallGraphBuilder.build(from: files)
        let columns = graph.fileColumns.map(\.filePath)
        #expect(columns.first == "Sources/App/AppFeature.swift")
        #expect(columns.contains("Sources/Inbox/InboxStore.swift"))
        #expect(graph.nodes.contains(where: { $0.symbolName == "AppFeature" }))
        #expect(graph.nodes.contains(where: { $0.symbolName == "InboxStore" }))
    }

    @Test("extractSymbols finds Kotlin fun")
    func kotlinSymbols() {
        let patch = """
        @@ -10,0 +11,3 @@
        +class TokenStore {
        +    fun refresh() {}
        +}
        """
        let symbols = ImportCallGraphBuilder.extractSymbols(from: patch, language: .kotlin)
        #expect(symbols.map(\.name).contains("TokenStore"))
        #expect(symbols.map(\.name).contains("refresh"))
    }

    @Test("symbol name references create edges even without import")
    func symbolReferenceEdges() {
        let files = [
            GitHubPullFile(
                filename: "A.swift",
                status: "modified", additions: 3, deletions: 0, changes: 3,
                patch: """
                @@ -1,0 +1,3 @@
                +struct Caller {
                +    let store = InboxStore()
                +}
                """
            ),
            GitHubPullFile(
                filename: "B.swift",
                status: "modified", additions: 2, deletions: 0, changes: 2,
                patch: """
                @@ -1,0 +1,2 @@
                +final class InboxStore {
                +}
                """
            ),
        ]
        let graph = ImportCallGraphBuilder.build(from: files)
        #expect(!graph.edges.isEmpty)
        #expect(graph.orderedNodes.first?.symbolName == "Caller")
    }

    @Test("topologicalFiles puts sources before sinks")
    func topo() {
        let paths = ["B.kt", "A.kt", "C.kt"]
        let nodes = [
            CallGraphNode(id: "a", symbolName: "A", kind: .type, filePath: "A.kt", line: 1, isChanged: true, order: 0),
            CallGraphNode(id: "b", symbolName: "B", kind: .type, filePath: "B.kt", line: 1, isChanged: true, order: 1),
            CallGraphNode(id: "c", symbolName: "C", kind: .type, filePath: "C.kt", line: 1, isChanged: true, order: 2),
        ]
        let edges = [
            CallGraphEdge(fromID: "a", toID: "b"),
            CallGraphEdge(fromID: "b", toID: "c"),
        ]
        let ordered = ImportCallGraphBuilder.topologicalFiles(paths: paths, edges: edges, nodes: nodes)
        #expect(ordered == ["A.kt", "B.kt", "C.kt"])
    }
}
