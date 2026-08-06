import SwiftUI

/// 呼び出し先/元が複数あるときの候補一覧（rinkaku の gd/gr ポップアップ相当）。
struct JumpPickerView: View {
    let picker: SymbolJumpPicker
    let onChoose: (CallGraphNode) -> Void
    let onCancel: () -> Void
    @State private var selectedID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(picker.kind.statusLabel)
                    .font(Theme.monoCaption.weight(.bold))
                    .foregroundStyle(Theme.accent)
                Text(picker.kind.title)
                    .font(Theme.monoCaption.weight(.semibold))
                Text("· \(picker.candidates.count)")
                    .font(Theme.monoCaption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("esc") { onCancel() }
                    .font(Theme.monoCaption2)
                    .foregroundStyle(.secondary)
                    .buttonStyle(.plain)
                    .keyboardShortcut(.cancelAction)
            }

            Text("j/k またはクリックで選択 · Enter でジャンプ")
                .font(Theme.monoCaption2)
                .foregroundStyle(.tertiary)

            List(selection: $selectedID) {
                ForEach(picker.candidates) { node in
                    HStack(spacing: 6) {
                        Text(node.isChanged ? "~" : " ")
                            .font(Theme.monoCaption2)
                            .foregroundStyle(Theme.warning)
                            .frame(width: 10)
                        Text(node.kind.label)
                            .font(Theme.monoCaption2)
                            .foregroundStyle(.secondary)
                            .frame(width: 36, alignment: .leading)
                        Text(node.symbolName)
                            .font(Theme.monoCaption.weight(.medium))
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Text("\((node.filePath as NSString).lastPathComponent):\(node.line)")
                            .font(Theme.monoCaption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                    .tag(node.id)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        onChoose(node)
                    }
                }
            }
            .listStyle(.plain)
            .frame(minHeight: 180, maxHeight: 320)

            HStack {
                Spacer()
                Button("cancel") { onCancel() }
                    .font(Theme.monoCaption)
                    .buttonStyle(.plain)
                Button("jump") {
                    if let id = selectedID,
                       let node = picker.candidates.first(where: { $0.id == id }) {
                        onChoose(node)
                    } else if let first = picker.candidates.first {
                        onChoose(first)
                    }
                }
                .font(Theme.monoCaption.weight(.bold))
                .foregroundStyle(Theme.accent)
                .buttonStyle(.plain)
                .keyboardShortcut(.defaultAction)
                .disabled(picker.candidates.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 480)
        .onAppear {
            selectedID = picker.candidates.first?.id
        }
    }
}
