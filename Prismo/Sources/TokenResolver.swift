import Foundation

/// GitHub トークンの解決。PAT（Keychain）を優先し、空なら `gh auth token`。
enum TokenResolver {
    static func resolve(pat: String) -> String? {
        let trimmed = pat.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        return ghAuthToken()
    }

    static func ghAuthToken() -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["gh", "auth", "token", "--hostname", "github.com"]
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
