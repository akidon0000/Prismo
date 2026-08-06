import Foundation
import Combine

/// ユーザー設定。トークンは Keychain、アカウント一覧とそれ以外は UserDefaults。
@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let defaults: UserDefaults
    private enum Key {
        static let githubTokenAccount = "githubToken"
        static let accounts = "githubAccounts"
        static let activeAccountID = "activeAccountID"
        static let preferAssignedFirst = "preferAssignedFirst"
        static let defaultCheckoutRoot = "defaultCheckoutRoot"
        static let useDemoData = "useDemoData"
        static let showAssignedOnly = "showAssignedOnly"
        static let diffSoftWrap = "diffSoftWrap"
        static let appearance = "appearance"
        static let legacyToken = "githubToken"
        static let didMigrateAccounts = "didMigrateAccounts"
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

    @Published private(set) var accounts: [GitHubAccount] {
        didSet { persistAccounts() }
    }

    @Published var activeAccountID: UUID? {
        didSet {
            if let activeAccountID {
                defaults.set(activeAccountID.uuidString, forKey: Key.activeAccountID)
            } else {
                defaults.removeObject(forKey: Key.activeAccountID)
            }
        }
    }

    /// アクティブアカウントの PAT（tokenMode == .pat のときのみ使用）。
    @Published var githubToken: String = "" {
        didSet {
            guard let id = activeAccountID,
                  let account = accounts.first(where: { $0.id == id }),
                  account.tokenMode == .pat else { return }
            KeychainStore.setString(githubToken, forKey: patKeychainKey(id))
        }
    }

    @Published var preferAssignedFirst: Bool {
        didSet { defaults.set(preferAssignedFirst, forKey: Key.preferAssignedFirst) }
    }

    @Published var defaultCheckoutRoot: String {
        didSet { defaults.set(defaultCheckoutRoot, forKey: Key.defaultCheckoutRoot) }
    }

    @Published var useDemoData: Bool {
        didSet { defaults.set(useDemoData, forKey: Key.useDemoData) }
    }

    @Published var showAssignedOnly: Bool {
        didSet { defaults.set(showAssignedOnly, forKey: Key.showAssignedOnly) }
    }

    @Published var diffSoftWrap: Bool {
        didSet { defaults.set(diffSoftWrap, forKey: Key.diffSoftWrap) }
    }

    @Published var appearance: Appearance {
        didSet { defaults.set(appearance.rawValue, forKey: Key.appearance) }
    }

    var activeAccount: GitHubAccount? {
        guard let activeAccountID else { return accounts.first }
        return accounts.first { $0.id == activeAccountID } ?? accounts.first
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

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

        if let data = defaults.data(forKey: Key.accounts),
           let decoded = try? JSONDecoder().decode([GitHubAccount].self, from: data),
           !decoded.isEmpty {
            self.accounts = decoded
        } else {
            self.accounts = []
        }

        if let idString = defaults.string(forKey: Key.activeAccountID),
           let id = UUID(uuidString: idString) {
            self.activeAccountID = id
        } else {
            self.activeAccountID = accounts.first?.id
        }

        migrateIfNeeded()
        reloadActivePAT()
    }

    // MARK: - Account management

    func selectAccount(_ id: UUID) {
        guard accounts.contains(where: { $0.id == id }) else { return }
        activeAccountID = id
        reloadActivePAT()
    }

    @discardableResult
    func addAccount(_ account: GitHubAccount, pat: String? = nil) -> GitHubAccount {
        let next = account
        if let existing = accounts.first(where: {
            $0.login == next.login && $0.host == next.host && $0.tokenMode == next.tokenMode
        }) {
            return existing
        }
        accounts.append(next)
        if next.tokenMode == .pat, let pat, !pat.isEmpty {
            KeychainStore.setString(pat, forKey: patKeychainKey(next.id))
        }
        if activeAccountID == nil {
            activeAccountID = next.id
        }
        reloadActivePAT()
        return next
    }

    func updateAccount(_ account: GitHubAccount) {
        guard let index = accounts.firstIndex(where: { $0.id == account.id }) else { return }
        accounts[index] = account
        if activeAccountID == account.id {
            reloadActivePAT()
        }
    }

    func removeAccount(_ id: UUID) {
        accounts.removeAll { $0.id == id }
        KeychainStore.setString(nil, forKey: patKeychainKey(id))
        if activeAccountID == id {
            activeAccountID = accounts.first?.id
            reloadActivePAT()
        }
    }

    /// `gh auth status` から未登録アカウントを取り込む。
    @discardableResult
    func importFromGhCLI() -> Int {
        let discovered = GhAuthAccountDiscovery.discover()
        var added = 0
        for item in discovered {
            let exists = accounts.contains { $0.login == item.login && $0.host == item.host && $0.tokenMode == .ghCLI }
            guard !exists else { continue }
            let label = item.host == "github.com" ? item.login : "\(item.login)@\(item.host)"
            let account = GitHubAccount(
                label: label,
                login: item.login,
                host: item.host,
                tokenMode: .ghCLI
            )
            accounts.append(account)
            added += 1
            if item.isActive, activeAccountID == nil || accounts.count == 1 {
                activeAccountID = account.id
            }
        }
        if activeAccountID == nil {
            activeAccountID = accounts.first?.id
        }
        reloadActivePAT()
        return added
    }

    func pat(for account: GitHubAccount) -> String {
        guard account.tokenMode == .pat else { return "" }
        return KeychainStore.string(forKey: patKeychainKey(account.id)) ?? ""
    }

    func setPAT(_ token: String, for accountID: UUID) {
        KeychainStore.setString(token, forKey: patKeychainKey(accountID))
        if activeAccountID == accountID {
            githubToken = token
        }
    }

    func makeClient() -> GitHubClient? {
        let account = activeAccount
        let pat = account.map { self.pat(for: $0) } ?? githubToken
        guard let token = TokenResolver.resolve(account: account, pat: pat) else { return nil }
        return GitHubClient(token: token, host: account?.host ?? "github.com")
    }

    // MARK: - Private

    private func patKeychainKey(_ id: UUID) -> String {
        "token.\(id.uuidString)"
    }

    private func persistAccounts() {
        if let data = try? JSONEncoder().encode(accounts) {
            defaults.set(data, forKey: Key.accounts)
        }
    }

    private func reloadActivePAT() {
        if let account = activeAccount, account.tokenMode == .pat {
            githubToken = KeychainStore.string(forKey: patKeychainKey(account.id)) ?? ""
        } else {
            // didSet で Keychain を消さないよう、pat 以外は空表示のみ
            if githubToken != "" {
                // bypass didSet side effect by direct assign only when not pat — didSet still runs
                // so temporarily we only clear UI field when not pat: use a flag… simpler: don't write keychain unless pat
            }
            githubToken = ""
        }
    }

    private func migrateIfNeeded() {
        guard !defaults.bool(forKey: Key.didMigrateAccounts) || accounts.isEmpty else { return }

        // 1) gh に入っているアカウントを取り込む
        if accounts.isEmpty {
            _ = importFromGhCLI()
        }

        // 2) 旧単一 Keychain トークンがあれば PAT アカウントとして残す
        let legacy =
            KeychainStore.string(forKey: Key.githubTokenAccount)
            ?? defaults.string(forKey: Key.legacyToken)
        if let legacy, !legacy.isEmpty {
            let hasPAT = accounts.contains { $0.tokenMode == .pat }
            if !hasPAT {
                let account = GitHubAccount(
                    label: "PAT",
                    login: "pat",
                    host: "github.com",
                    tokenMode: .pat
                )
                accounts.append(account)
                KeychainStore.setString(legacy, forKey: patKeychainKey(account.id))
                if activeAccountID == nil {
                    activeAccountID = account.id
                }
            }
            defaults.removeObject(forKey: Key.legacyToken)
        }

        if activeAccountID == nil {
            activeAccountID = accounts.first?.id
        }
        defaults.set(true, forKey: Key.didMigrateAccounts)
        persistAccounts()
    }
}
