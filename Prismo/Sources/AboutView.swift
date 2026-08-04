import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.1"
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
                .symbolRenderingMode(.hierarchical)

            Text("Prismo")
                .font(.largeTitle.weight(.bold))

            Text("See the shape of a PR before you read it.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Text("Version \(version)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.tertiary)

            Divider()

            Text("呼び出しグラフの順で差分を読み、アサイン済みレビューを先に片付ける macOS アプリです。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button("閉じる") { dismiss() }
                .keyboardShortcut(.defaultAction)
        }
        .padding(28)
        .frame(width: 360)
    }
}
