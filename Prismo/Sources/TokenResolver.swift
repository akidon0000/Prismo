import Foundation

/// アクティブアカウントに応じてトークンを解決する。
enum TokenResolver {
    static func resolve(account: GitHubAccount?, pat: String) -> String? {
        guard let account else {
            return resolveLegacy(pat: pat)
        }
        switch account.tokenMode {
        case .pat:
            let trimmed = pat.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        case .ghCLI:
            return ghAuthToken(hostname: account.host, user: account.login)
        }
    }

    /// 旧設定（単一トークン）互換。
    static func resolveLegacy(pat: String) -> String? {
        let trimmed = pat.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        return ghAuthToken(hostname: "github.com", user: nil)
    }

    /// `gh auth token`。`--user` / `--hostname` で Enterprise・複数アカウントに対応。
    static func ghAuthToken(hostname: String, user: String?) -> String? {
        var args = ["gh", "auth", "token", "--hostname", GitHubAccount.normalizeHost(hostname)]
        if let user, !user.isEmpty {
            args += ["--user", user]
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }
        guard process.terminationStatus == 0 else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let token = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let token, !token.isEmpty else { return nil }
        return token
    }
}
