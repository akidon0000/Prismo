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
        static let showAssignedOnly = "showAssignedOnly"
        static let diffSoftWrap = "diffSoftWrap"
        static let appearance = "appearance"
        static let legacyToken = "githubToken" // UserDefaults からの移行用
    }

    enum Appearance: String, CaseIterable, Identifiable {
        case system, light, dark
        var id: String { rawValue }
        var label: String {
            switch self {
            case .system: return "システム"
            case .light: return "ライト"
            case .dark: return "ダーク"
            }
        }
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

    /// アサイン済み PR だけを一覧に表示する。
    @Published var showAssignedOnly: Bool {
        didSet { defaults.set(showAssignedOnly, forKey: Key.showAssignedOnly) }
    }

    /// Diff 行を折り返して表示する。
    @Published var diffSoftWrap: Bool {
        didSet { defaults.set(diffSoftWrap, forKey: Key.diffSoftWrap) }
    }

    /// 外観（システム / ライト / ダーク）。
    @Published var appearance: Appearance {
        didSet { defaults.set(appearance.rawValue, forKey: Key.appearance) }
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
        self.showAssignedOnly = defaults.object(forKey: Key.showAssignedOnly) as? Bool ?? false
        self.diffSoftWrap = defaults.object(forKey: Key.diffSoftWrap) as? Bool ?? true
        if let raw = defaults.string(forKey: Key.appearance), let value = Appearance(rawValue: raw) {
            self.appearance = value
        } else {
            self.appearance = .system
        }
    }
}
