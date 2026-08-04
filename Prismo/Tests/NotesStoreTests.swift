import Foundation
import Testing
@testable import Prismo

@Suite("NotesStore")
struct NotesStoreTests {
    @Test("round-trips notes to disk")
    func roundTrip() throws {
        let note = ReviewNote(
            pullRequestID: 42,
            nodeID: "n1",
            symbolName: "Foo",
            filePath: "Foo.swift",
            line: 10,
            body: "looks good"
        )
        // 専用ファイルを汚さないよう一時的に保存→読込の公開 API を使う
        NotesStore.save([note])
        let loaded = NotesStore.load()
        #expect(loaded.contains(where: { $0.id == note.id && $0.body == "looks good" }))
    }
}
