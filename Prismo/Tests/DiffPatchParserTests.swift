import Testing
@testable import Prismo

@Suite("DiffPatchParser")
struct DiffPatchParserTests {
    @Test("parses additions with new line numbers")
    func parseAdditions() {
        let patch = """
        @@ -10,2 +10,4 @@
         context
        +added one
        +added two
         still
        """
        let lines = DiffPatchParser.parse(patch)
        let adds = lines.filter { $0.kind == .addition }
        #expect(adds.count == 2)
        #expect(adds[0].newLine == 11)
        #expect(adds[1].newLine == 12)
    }

    @Test("focused returns nearby lines")
    func focused() {
        let patch = """
        @@ -1,1 +40,5 @@
         keep
        +class TokenStore {
        +    fun refresh() {}
        +}
         end
        """
        let focused = DiffPatchParser.focused(patch: patch, aroundLine: 41, radius: 2)
        #expect(!focused.isEmpty)
        #expect(focused.contains(where: { $0.text.contains("TokenStore") }))
    }
}
