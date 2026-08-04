import Foundation
import Testing
@testable import Prismo

@Suite("LocalRepoLocator")
struct LocalRepoLocatorTests {
    @Test("candidates include ghq path first")
    func ghqFirst() {
        let dirs = LocalRepoLocator.candidateDirectories(
            owner: "akidon0000",
            name: "Prismo",
            checkoutRoot: ""
        )
        let paths = dirs.map(\.path)
        #expect(paths.contains { $0.hasSuffix("ghq/github.com/akidon0000/Prismo") })
        #expect(paths.first?.hasSuffix("ghq/github.com/akidon0000/Prismo") == true)
    }

    @Test("finds this repository under ghq when present")
    func findsSelf() {
        let found = LocalRepoLocator.find(owner: "akidon0000", name: "Prismo", checkoutRoot: "")
        // このマシンの開発環境では存在する想定。無い CI ではスキップ相当に緩く見る。
        if let found {
            #expect(LocalRepoLocator.isGitRepo(found))
            #expect(found.path.contains("Prismo"))
        }
    }
}
