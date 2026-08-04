import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            Section("GitHub") {
                SecureField("Personal Access Token", text: $settings.githubToken)
                Text("repo と read:user スコープが必要です。トークンは Keychain へ移す予定です。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("インボックス") {
                Toggle("アサイン済みを先頭に表示", isOn: $settings.preferAssignedFirst)
            }

            Section("Checkout") {
                TextField("クローン親ディレクトリ", text: $settings.defaultCheckoutRoot)
                Text("空の場合は一時ディレクトリを使います。実装は後続です。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("対応言語") {
                LabeledContent("パーサ") {
                    Text("Swift · Kotlin · Dart")
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 360)
    }
}
