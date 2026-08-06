import Foundation
import SwiftUI
import Testing
@testable import Prismo

@Suite("Diff symbol linker")
struct DiffSymbolLinkerTests {
    private func links(in attributed: AttributedString) -> [String] {
        attributed.runs.compactMap { run in
            guard run.link != nil else { return nil }
            return String(attributed[run.range].characters)
        }
    }

    @Test("known symbols become links, others stay plain")
    func linkKnownSymbols() {
        let attributed = DiffSymbolLinker.attributed(
            "let user = fetchUser(id: userID)",
            symbols: ["fetchUser", "render"],
            baseColor: .primary
        )
        #expect(links(in: attributed) == ["fetchUser"])
        #expect(String(attributed.characters) == "let user = fetchUser(id: userID)")
    }

    @Test("identifier boundaries are respected")
    func wordBoundaries() {
        // "fetchUserAll" は別識別子なのでリンクしない
        let attributed = DiffSymbolLinker.attributed(
            "fetchUserAll() + fetchUser()",
            symbols: ["fetchUser"],
            baseColor: .primary
        )
        #expect(links(in: attributed) == ["fetchUser"])
    }

    @Test("link URL round-trips symbol name")
    func urlRoundTrip() {
        let attributed = DiffSymbolLinker.attributed(
            "render()",
            symbols: ["render"],
            baseColor: .primary
        )
        let url = attributed.runs.compactMap(\.link).first
        #expect(url != nil)
        #expect(DiffSymbolLinker.symbolName(from: url!) == "render")
        #expect(DiffSymbolLinker.symbolName(from: URL(string: "https://example.com/render")!) == nil)
    }
}
