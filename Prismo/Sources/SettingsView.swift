import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @State private var draftLabel = ""
    @State private var draftLogin = ""
    @State private var draftHost = "github.com"
    @State private var draftMode: GitHubAccount.TokenMode = .ghCLI
    @State private var draftPAT = ""
    @State private var importMessage: String?

    var body: some View {
        Form {
            Section("アカウント") {
                if settings.accounts.isEmpty {
                    Text("アカウントがありません。`gh` から取り込むか、下で追加してください。")
                        .font(Theme.monoCaption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(settings.accounts) { account in
                        HStack(spacing: 8) {
                            Button {
                                settings.selectAccount(account.id)
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: settings.activeAccountID == account.id ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(Theme.accent)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(account.displayTitle)
                                            .font(Theme.monoCaption.weight(.medium))
                                        Text("\(account.tokenMode.label) · \(account.host)")
                                            .font(Theme.monoCaption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            Spacer()
                            Button(role: .destructive) {
                                settings.removeAccount(account.id)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }

                Button("gh CLI から取り込む") {
                    let n = settings.importFromGhCLI()
                    importMessage = n == 0 ? "新しいアカウントはありません" : "\(n) 件取り込みました"
                }
                if let importMessage {
                    Text(importMessage)
                        .font(Theme.monoCaption2)
                        .foregroundStyle(.secondary)
                }
            }

            Section("アカウントを追加") {
                TextField("表示名", text: $draftLabel)
                TextField("login（gh のユーザー名）", text: $draftLogin)
                TextField("ホスト（github.com / ghe.example.com）", text: $draftHost)
                Picker("認証", selection: $draftMode) {
                    ForEach(GitHubAccount.TokenMode.allCases, id: \.self) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                if draftMode == .pat {
                    SecureField("Personal Access Token", text: $draftPAT)
                }
                Button("追加") {
                    addDraftAccount()
                }
                .disabled(draftLogin.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Text("Enterprise Server はホスト名を入れ、PAT か `gh auth login --hostname` 済みの gh CLI を使います。github.com 上の EMU / 会社アカウントは login を分けて切り替えます。")
                    .font(Theme.monoCaption2)
                    .foregroundStyle(.secondary)
            }

            if let account = settings.activeAccount, account.tokenMode == .pat {
                Section("アクティブ PAT") {
                    SecureField("Token", text: $settings.githubToken)
                    Text("スコープ: repo（プライベート）と read:user。Keychain に保存します。")
                        .font(Theme.monoCaption2)
                        .foregroundStyle(.secondary)
                }
            }

            Section("インボックス") {
                Toggle("デモデータを使う", isOn: $settings.useDemoData)
                Toggle("アサイン済みを先頭に表示", isOn: $settings.preferAssignedFirst)
                Toggle("アサイン済みのみ表示", isOn: $settings.showAssignedOnly)
            }

            Section("Checkout") {
                TextField("クローン親ディレクトリ", text: $settings.defaultCheckoutRoot)
                Text("空の場合は一時ディレクトリ（~/…/PrismoCheckouts）を使います。")
                    .font(Theme.monoCaption2)
                    .foregroundStyle(.secondary)
            }

            Section("外観") {
                Picker("テーマ", selection: $settings.appearance) {
                    ForEach(AppSettings.Appearance.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Diff") {
                Toggle("長い行を折り返す", isOn: $settings.diffSoftWrap)
            }

            Section("対応言語") {
                LabeledContent("パーサ") {
                    Text("Swift · Kotlin · Dart")
                }
                Text("現状は import / 宣言のヒューリスティック。tree-sitter 連携は後続。")
                    .font(Theme.monoCaption2)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .tint(Theme.accent)
        .frame(width: 560, height: 620)
    }

    private func addDraftAccount() {
        let login = draftLogin.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !login.isEmpty else { return }
        let label = draftLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        let account = GitHubAccount(
            label: label.isEmpty ? login : label,
            login: login,
            host: draftHost,
            tokenMode: draftMode
        )
        let created = settings.addAccount(account, pat: draftMode == .pat ? draftPAT : nil)
        settings.selectAccount(created.id)
        draftLabel = ""
        draftLogin = ""
        draftHost = "github.com"
        draftMode = .ghCLI
        draftPAT = ""
    }
}
