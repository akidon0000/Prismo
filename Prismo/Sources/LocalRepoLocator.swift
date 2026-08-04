import Foundation

/// 既存のローカル clone を探す（ghq / 設定ルート）。無ければ nil。
enum LocalRepoLocator {
    static func find(owner: String, name: String, checkoutRoot: String) -> URL? {
        let candidates = candidateDirectories(owner: owner, name: name, checkoutRoot: checkoutRoot)
        return candidates.first { isGitRepo($0) }
    }

    static func candidateDirectories(owner: String, name: String, checkoutRoot: String) -> [URL] {
        var urls: [URL] = []
        let home = URL(fileURLWithPath: NSHomeDirectory())

        // ghq 既定
        urls.append(
            home
                .appendingPathComponent("ghq/github.com")
                .appendingPathComponent(owner)
                .appendingPathComponent(name)
        )

        // GHQ_ROOT があれば
        if let ghqRoot = ProcessInfo.processInfo.environment["GHQ_ROOT"], !ghqRoot.isEmpty {
            urls.append(
                URL(fileURLWithPath: (ghqRoot as NSString).expandingTildeInPath)
                    .appendingPathComponent("github.com")
                    .appendingPathComponent(owner)
                    .appendingPathComponent(name)
            )
        }

        // アプリ設定の checkout ルート
        let configured = CheckoutService.resolveRoot(checkoutRoot)
            .appendingPathComponent(owner)
            .appendingPathComponent(name)
        urls.append(configured)

        // 重複除去（パス正規化）
        var seen = Set<String>()
        return urls.filter { seen.insert($0.standardizedFileURL.path).inserted }
    }

    static func isGitRepo(_ url: URL) -> Bool {
        let git = url.appendingPathComponent(".git")
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: git.path, isDirectory: &isDir) {
            return true // dir or file (worktree/gitfile)
        }
        return false
    }
}
