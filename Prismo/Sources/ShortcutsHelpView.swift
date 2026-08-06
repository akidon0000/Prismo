import SwiftUI

struct ShortcutsHelpView: View {
    @Environment(\.dismiss) private var dismiss

    private let rows: [(keys: String, action: String)] = [
        ("⌘R", "インボックスを更新"),
        ("⌘J / ⌘K", "次 / 前のシンボル"),
        ("⇧⌘J", "IDE へジャンプ"),
        ("⇧⌘]", "呼び出し先へ（gd）"),
        ("⇧⌘[", "呼び出し元へ（gr）"),
        ("⇧⌘B", "影響範囲一覧（blast）"),
        ("⌘[ / ⌘]", "ジャンプ履歴 戻る / 進む"),
        ("⇧⌘N", "メモを追加"),
        ("⇧⌘C", "メモを Markdown コピー"),
        ("⌘/", "このショートカット一覧"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("shortcuts")
                .font(Theme.monoCallout.weight(.bold))
                .foregroundStyle(Theme.accent)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(rows, id: \.keys) { row in
                    HStack(alignment: .firstTextBaseline) {
                        Text(row.keys)
                            .font(Theme.monoCaption)
                            .foregroundStyle(Theme.accent)
                            .frame(width: 100, alignment: .leading)
                        Text(row.action)
                            .font(Theme.monoCaption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            HStack {
                Spacer()
                Button("close") { dismiss() }
                    .font(Theme.monoCaption)
                    .foregroundStyle(Theme.accent)
                    .buttonStyle(.plain)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 420)
    }
}
