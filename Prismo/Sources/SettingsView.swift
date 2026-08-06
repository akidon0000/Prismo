import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            Section("GitHub") {
                SecureField("Personal Access Token", text: $settings.githubToken)
                Text("スコープ: repo（プライベート）と read:user。Keychain に保存します。空の場合は `gh auth token` を使います。")
                    .font(Theme.monoCaption2)
                    .foregroundStyle(.secondary)
            }

            Section("インボックス") {
                Toggle("デモデータを使う", isOn: $settings.useDemoData)
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
        .frame(width: 480, height: 320)
    }
}
