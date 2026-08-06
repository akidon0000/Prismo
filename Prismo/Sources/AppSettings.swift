import Foundation
import Combine

/// ユーザー設定。トークンは Keychain、それ以外は UserDefaults。
@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let defaults: UserDefaults
    private enum Key {
        static let githubTokenAccount = "githubToken"
        static let useDemoData = "useDemoData"
    }

    /// GitHub PAT。空なら `gh auth token` にフォールバックする。
    @Published var githubToken: String = "" {
        didSet { KeychainStore.setString(githubToken, forKey: Key.githubTokenAccount) }
    }

    @Published var useDemoData: Bool {
        didSet { defaults.set(useDemoData, forKey: Key.useDemoData) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.useDemoData = defaults.object(forKey: Key.useDemoData) as? Bool ?? false
        self.githubToken = KeychainStore.string(forKey: Key.githubTokenAccount) ?? ""
    }

    func makeClient() -> GitHubClient? {
        guard let token = TokenResolver.resolve(pat: githubToken) else { return nil }
        return GitHubClient(token: token)
    }
}
