import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            Section("GitHub") {
                SecureField("Personal Access Token（任意）", text: $settings.githubToken)
                Text("空のときは `gh auth token` を使います。スコープは repo（プライベート）と read:user。トークンは Keychain に保存します。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle("デモデータを使う", isOn: $settings.useDemoData)
            }

            Section("インボックス") {
                Toggle("アサイン済みを先頭に表示", isOn: $settings.preferAssignedFirst)
                Toggle("アサイン済みのみ表示", isOn: $settings.showAssignedOnly)
            }

            Section("Checkout") {
                TextField("クローン親ディレクトリ", text: $settings.defaultCheckoutRoot)
                Text("空の場合は一時ディレクトリ（~/…/PrismoCheckouts）を使います。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("対応言語") {
                LabeledContent("パーサ") {
                    Text("Swift · Kotlin · Dart")
                }
                Text("現状は import / 宣言のヒューリスティック。tree-sitter 連携は後続。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 420)
    }
}
