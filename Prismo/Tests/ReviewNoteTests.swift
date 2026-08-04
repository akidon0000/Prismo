import Foundation
import Testing
@testable import Prismo

@Suite("ReviewNoteExporter")
struct ReviewNoteTests {
    @Test("markdown lists notes with file anchors")
    func markdownExport() {
        let pr = PullRequest(
            id: 99, number: 7, title: "Demo",
            repository: "a/b", owner: "a", name: "b",
            author: "me",
            url: URL(string: "https://github.com/a/b/pull/7")!,
            isAssignedToMe: true, language: .swift,
            updatedAt: Date(),
            headRef: "feat", headSHA: "abc",
            cloneURL: "https://github.com/a/b.git",
            sshURL: "git@github.com:a/b.git"
        )
        let notes = [
            ReviewNote(
                pullRequestID: 99,
                nodeID: "n1",
                symbolName: "InboxStore",
                filePath: "Sources/InboxStore.swift",
                line: 18,
                body: "nil チェックが足りない"
            )
        ]
        let md = ReviewNoteExporter.markdown(for: notes, pr: pr)
        #expect(md.contains("#7"))
        #expect(md.contains("`InboxStore`"))
        #expect(md.contains("Sources/InboxStore.swift:18"))
        #expect(md.contains("nil チェックが足りない"))
    }
}
