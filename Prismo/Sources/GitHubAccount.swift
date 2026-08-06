import Foundation

/// GitHub.com / Enterprise / EMU など、切り替え可能なアカウント。
struct GitHubAccount: Identifiable, Codable, Hashable, Sendable {
    enum TokenMode: String, Codable, Sendable, CaseIterable {
        /// `gh auth token --user … --hostname …`
        case ghCLI
        /// Keychain に保存した PAT / fine-grained token
        case pat

        var label: String {
            switch self {
            case .ghCLI: return "gh CLI"
            case .pat: return "PAT"
            }
        }
    }

    var id: UUID
    /// UI 表示名（例: Work / Personal）
    var label: String
    /// `gh` の login、または表示用ログイン名
    var login: String
    /// `github.com` または Enterprise ホスト名
    var host: String
    var tokenMode: TokenMode

    init(
        id: UUID = UUID(),
        label: String,
        login: String,
        host: String = "github.com",
        tokenMode: TokenMode = .ghCLI
    ) {
        self.id = id
        self.label = label
        self.login = login
        self.host = Self.normalizeHost(host)
        self.tokenMode = tokenMode
    }

    var displayTitle: String {
        let hostSuffix = host == "github.com" ? "" : "@\(host)"
        if label.isEmpty || label == login {
            return "\(login)\(hostSuffix)"
        }
        return "\(label) (\(login)\(hostSuffix))"
    }

    var shortTitle: String {
        label.isEmpty ? login : label
    }

    static func normalizeHost(_ raw: String) -> String {
        var h = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        h = h.replacingOccurrences(of: "https://", with: "")
        h = h.replacingOccurrences(of: "http://", with: "")
        if let slash = h.firstIndex(of: "/") {
            h = String(h[..<slash])
        }
        return h.isEmpty ? "github.com" : h.lowercased()
    }
}

enum GitHubHost {
    /// REST API のベース（末尾スラッシュなし）。
    static func apiBaseURL(for host: String) -> URL {
        let h = GitHubAccount.normalizeHost(host)
        if h == "github.com" {
            return URL(string: "https://api.github.com")!
        }
        // GitHub Enterprise Server / 多くの GHE は /api/v3
        return URL(string: "https://\(h)/api/v3")!
    }

    static func webBaseURL(for host: String) -> URL {
        let h = GitHubAccount.normalizeHost(host)
        return URL(string: "https://\(h)")!
    }

    static func cloneHTTPS(owner: String, repo: String, host: String) -> String {
        let h = GitHubAccount.normalizeHost(host)
        return "https://\(h)/\(owner)/\(repo).git"
    }

    static func cloneSSH(owner: String, repo: String, host: String) -> String {
        let h = GitHubAccount.normalizeHost(host)
        return "git@\(h):\(owner)/\(repo).git"
    }
}

/// `gh auth status --json hosts` からアカウント候補を取り出す。
enum GhAuthAccountDiscovery {
    struct HostAccount: Sendable {
        let host: String
        let login: String
        let isActive: Bool
    }

    static func discover() -> [HostAccount] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["gh", "auth", "status", "--json", "hosts"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return []
        }
        guard process.terminationStatus == 0 else { return nilIfEmpty() }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return parse(data: data)
    }

    private static func nilIfEmpty() -> [HostAccount] { [] }

    static func parse(data: Data) -> [HostAccount] {
        struct Root: Decodable {
            let hosts: [String: [Entry]]
        }
        struct Entry: Decodable {
            let host: String?
            let login: String
            let active: Bool?
            let state: String?
        }
        guard let root = try? JSONDecoder().decode(Root.self, from: data) else { return [] }
        var result: [HostAccount] = []
        for (hostKey, entries) in root.hosts {
            for entry in entries {
                guard entry.state == nil || entry.state == "success" else { continue }
                result.append(
                    HostAccount(
                        host: entry.host ?? hostKey,
                        login: entry.login,
                        isActive: entry.active ?? false
                    )
                )
            }
        }
        return result.sorted { lhs, rhs in
            if lhs.isActive != rhs.isActive { return lhs.isActive && !rhs.isActive }
            return lhs.login < rhs.login
        }
    }
}
