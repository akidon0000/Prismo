import Foundation
import Combine

/// ユーザー設定。UserDefaults に永続化する。
@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let defaults: UserDefaults
    private enum Key {
        static let githubToken = "githubToken"
        static let preferAssignedFirst = "preferAssignedFirst"
        static let defaultCheckoutRoot = "defaultCheckoutRoot"
    }

    /// GitHub Personal Access Token（repo + read:user）。空なら未設定。
    @Published var githubToken: String {
        didSet { defaults.set(githubToken, forKey: Key.githubToken) }
    }

    /// アサイン済みレビューを一覧の先頭に寄せる。
    @Published var preferAssignedFirst: Bool {
        didSet { defaults.set(preferAssignedFirst, forKey: Key.preferAssignedFirst) }
    }

    /// ブランチ checkout 先の親ディレクトリ。空なら一時領域。
    @Published var defaultCheckoutRoot: String {
        didSet { defaults.set(defaultCheckoutRoot, forKey: Key.defaultCheckoutRoot) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.githubToken = defaults.string(forKey: Key.githubToken) ?? ""
        self.preferAssignedFirst = defaults.object(forKey: Key.preferAssignedFirst) as? Bool ?? true
        self.defaultCheckoutRoot = defaults.string(forKey: Key.defaultCheckoutRoot) ?? ""
    }
}
