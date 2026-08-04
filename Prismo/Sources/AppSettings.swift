import Foundation
import Combine

/// ユーザー設定。トークンは Keychain、それ以外は UserDefaults。
@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let defaults: UserDefaults
    private enum Key {
        static let githubTokenAccount = "githubToken"
        static let preferAssignedFirst = "preferAssignedFirst"
        static let defaultCheckoutRoot = "defaultCheckoutRoot"
        static let useDemoData = "useDemoData"
        static let legacyToken = "githubToken" // UserDefaults からの移行用
    }

    /// GitHub Personal Access Token。空なら `gh auth token` へフォールバック。
    @Published var githubToken: String {
        didSet { KeychainStore.setString(githubToken, forKey: Key.githubTokenAccount) }
    }

    /// アサイン済みレビューを一覧の先頭に寄せる。
    @Published var preferAssignedFirst: Bool {
        didSet { defaults.set(preferAssignedFirst, forKey: Key.preferAssignedFirst) }
    }

    /// ブランチ checkout 先の親ディレクトリ。空なら一時領域。
    @Published var defaultCheckoutRoot: String {
        didSet { defaults.set(defaultCheckoutRoot, forKey: Key.defaultCheckoutRoot) }
    }

    /// 強制的にデモデータを使う（オフライン確認用）。
    @Published var useDemoData: Bool {
        didSet { defaults.set(useDemoData, forKey: Key.useDemoData) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if let keychain = KeychainStore.string(forKey: Key.githubTokenAccount), !keychain.isEmpty {
            self.githubToken = keychain
        } else if let legacy = defaults.string(forKey: Key.legacyToken), !legacy.isEmpty {
            // UserDefaults → Keychain 移行
            KeychainStore.setString(legacy, forKey: Key.githubTokenAccount)
            defaults.removeObject(forKey: Key.legacyToken)
            self.githubToken = legacy
        } else {
            self.githubToken = ""
        }

        self.preferAssignedFirst = defaults.object(forKey: Key.preferAssignedFirst) as? Bool ?? true
        self.defaultCheckoutRoot = defaults.string(forKey: Key.defaultCheckoutRoot) ?? ""
        self.useDemoData = defaults.object(forKey: Key.useDemoData) as? Bool ?? false
    }
}
