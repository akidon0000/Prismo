import SwiftUI
import AppKit

struct DiffPaneView: View {
    let filePath: String?
    let symbolName: String?
    let focusLine: Int
    let lines: [DiffLine]
    let canJump: Bool
    let onJump: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "doc.text")
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(filePath ?? "ファイル未選択")
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .textSelection(.enabled)
                    if let symbolName {
                        Text("\(symbolName) · L\(focusLine)")
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button(action: onJump) {
                    Label("Jump", systemImage: "arrow.right.circle")
                }
                .disabled(!canJump || filePath == nil)
                .help(canJump ? "IDE でこの行を開く" : "先に Checkout してください")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            if lines.isEmpty {
                ContentUnavailableView(
                    "Diff なし",
                    systemImage: "text.alignleft",
                    description: Text("シンボルを選ぶと、該当ファイルの patch をここに表示します。")
                )
            } else {
                ScrollViewReader { proxy in
                    ScrollView([.vertical, .horizontal]) {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(lines) { line in
                                DiffLineRow(line: line, highlighted: line.newLine == focusLine)
                                    .id(line.id)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onAppear {
                        scrollToFocus(proxy)
                    }
                    .onChange(of: focusLine) { _, _ in
                        scrollToFocus(proxy)
                    }
                    .onChange(of: filePath) { _, _ in
                        scrollToFocus(proxy)
                    }
                }
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    private func scrollToFocus(_ proxy: ScrollViewProxy) {
        if let target = lines.first(where: { $0.newLine == focusLine })?.id
            ?? lines.first(where: { $0.kind == .addition })?.id {
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 0.2)) {
                    proxy.scrollTo(target, anchor: .center)
                }
            }
        }
    }
}

private struct DiffLineRow: View {
    let line: DiffLine
    let highlighted: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(lineNumberLabel)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(width: 44, alignment: .trailing)
                .padding(.trailing, 8)
            Text(line.text)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(foreground)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 1)
        .background(background)
    }

    private var lineNumberLabel: String {
        if let n = line.newLine { return "\(n)" }
        if let o = line.oldLine { return "\(o)" }
        return ""
    }

    private var foreground: Color {
        switch line.kind {
        case .addition: return Color(red: 0.15, green: 0.55, blue: 0.25)
        case .deletion: return Color(red: 0.75, green: 0.2, blue: 0.2)
        case .header: return .secondary
        case .meta: return .secondary.opacity(0.7)
        case .context: return .primary
        }
    }

    private var background: Color {
        if highlighted { return Color.accentColor.opacity(0.18) }
        switch line.kind {
        case .addition: return Color.green.opacity(0.12)
        case .deletion: return Color.red.opacity(0.10)
        case .header: return Color.primary.opacity(0.04)
        default: return .clear
        }
    }
}
