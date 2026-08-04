import SwiftUI

struct ShortcutsHelpView: View {
    @Environment(\.dismiss) private var dismiss

    private let rows: [(keys: String, action: String)] = [
        ("⌘R", "インボックスを更新"),
        ("⌘J", "次のシンボル"),
        ("⌘K", "前のシンボル"),
        ("⇧⌘J", "IDE へジャンプ"),
        ("⇧⌘N", "メモを追加"),
        ("⇧⌘C", "メモを Markdown コピー"),
        ("⌘/", "このショートカット一覧"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("ショートカット")
                .font(.headline)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(rows, id: \.keys) { row in
                    HStack {
                        Text(row.keys)
                            .font(.body.monospaced())
                            .frame(width: 72, alignment: .leading)
                        Text(row.action)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            HStack {
                Spacer()
                Button("閉じる") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 360)
    }
}
