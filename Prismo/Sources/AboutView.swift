import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.1"
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(Theme.accent)
                .symbolRenderingMode(.hierarchical)

            Text("Prismo")
                .font(.largeTitle.weight(.semibold))

            Text("See the shape of a PR before you read it.")
                .font(Theme.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Text("バージョン \(version)")
                .font(Theme.caption)
                .foregroundStyle(.tertiary)

            Divider()

            Text("レビュー依頼を先に見せ、呼び出し順の輪郭から差分を読む macOS アプリです。")
                .font(Theme.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button("閉じる") { dismiss() }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
        }
        .padding(28)
        .frame(width: 360)
    }
}
