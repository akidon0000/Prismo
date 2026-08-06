import SwiftUI

struct DiffPaneView: View {
    let filePath: String?
    let symbolName: String?
    let focusLine: Int
    let lines: [DiffLine]

    var body: some View {
        ContentPane(
            title: "差分",
            symbol: "doc.text",
            trailing: headerTrailing
        ) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(filePath ?? "シンボルを選択してください")
                        .font(Theme.caption)
                        .foregroundStyle(filePath == nil ? .secondary : .primary)
                        .lineLimit(1)
                        .textSelection(.enabled)
                    if let symbolName {
                        Text("\(symbolName)  ·  行 \(focusLine)")
                            .font(Theme.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 8)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider().opacity(0.45)

            if lines.isEmpty {
                ContentUnavailableView(
                    "差分はここに表示されます",
                    systemImage: "text.alignleft",
                    description: Text("左の輪郭からシンボルを選ぶと、該当箇所の patch が開きます。")
                )
                .frame(maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(lines) { line in
                                DiffLineRow(line: line, highlighted: line.newLine == focusLine)
                                    .id(line.id)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                    .onAppear { scrollToFocus(proxy) }
                    .onChange(of: focusLine) { _, _ in scrollToFocus(proxy) }
                    .onChange(of: filePath) { _, _ in scrollToFocus(proxy) }
                }
            }
        }
    }

    private var headerTrailing: String? {
        guard let filePath else { return nil }
        return (filePath as NSString).lastPathComponent
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
            Text(gutter)
                .font(Theme.monoCaption2.weight(.bold))
                .foregroundStyle(gutterColor)
                .frame(width: 14, alignment: .center)
            Text(lineNumberLabel)
                .font(Theme.monoCaption2)
                .foregroundStyle(.tertiary)
                .frame(width: 40, alignment: .trailing)
                .padding(.trailing, 10)
            Text(line.text)
                .font(Theme.monoCaption)
                .foregroundStyle(foreground)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 1)
        .background(background)
    }

    private var gutter: String {
        switch line.kind {
        case .addition: return "+"
        case .deletion: return "-"
        case .header: return "⋯"
        default: return " "
        }
    }

    private var gutterColor: Color {
        switch line.kind {
        case .addition: return Theme.addition
        case .deletion: return Theme.deletion
        case .header: return .secondary
        default: return .secondary
        }
    }

    private var lineNumberLabel: String {
        if let n = line.newLine { return "\(n)" }
        if let o = line.oldLine { return "\(o)" }
        return ""
    }

    private var foreground: Color {
        switch line.kind {
        case .addition: return Theme.addition
        case .deletion: return Theme.deletion
        case .header, .meta: return .secondary
        case .context: return .primary
        }
    }

    private var background: Color {
        if highlighted { return Theme.accent.opacity(0.12) }
        switch line.kind {
        case .addition: return Theme.addition.opacity(0.08)
        case .deletion: return Theme.deletion.opacity(0.08)
        case .header: return Color.primary.opacity(0.03)
        default: return .clear
        }
    }
}
