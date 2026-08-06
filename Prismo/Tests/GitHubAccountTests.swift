import Testing
@testable import Prismo

@Suite("GitHub accounts")
struct GitHubAccountTests {
    @Test("api base URL maps github.com and enterprise hosts")
    func apiBaseURL() {
        #expect(GitHubHost.apiBaseURL(for: "github.com").absoluteString == "https://api.github.com")
        #expect(GitHubHost.apiBaseURL(for: "https://ghe.example.com/").absoluteString == "https://ghe.example.com/api/v3")
        #expect(GitHubHost.cloneSSH(owner: "o", repo: "r", host: "ghe.example.com") == "git@ghe.example.com:o/r.git")
    }

    @Test("gh auth status JSON is parsed into host accounts")
    func parseGhStatus() throws {
        let json = """
        {"hosts":{"github.com":[
          {"state":"success","active":true,"host":"github.com","login":"akidon0000"},
          {"state":"success","active":false,"host":"github.com","login":"akihiro-matsuyama_sansan"}
        ]}}
        """.data(using: .utf8)!
        let accounts = GhAuthAccountDiscovery.parse(data: json)
        #expect(accounts.count == 2)
        #expect(accounts[0].login == "akidon0000")
        #expect(accounts[0].isActive)
        #expect(accounts[1].login == "akihiro-matsuyama_sansan")
    }

    @Test("account display includes enterprise host")
    func displayTitle() {
        let account = GitHubAccount(label: "Work", login: "emu-user", host: "github.com", tokenMode: .ghCLI)
        #expect(account.displayTitle.contains("Work"))
        let ghe = GitHubAccount(label: "", login: "dev", host: "ghe.example.com", tokenMode: .pat)
        #expect(ghe.displayTitle.contains("ghe.example.com"))
    }
}
