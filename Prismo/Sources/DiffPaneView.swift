import SwiftUI
import AppKit

/// 差分テキスト内の既知シンボルをリンク化する（タップでシンボルジャンプ）。
enum DiffSymbolLinker {
    static let scheme = "prismo-symbol"

    /// `text` 中の識別子のうち `symbols` に含まれるものへリンクを張る。
    static func attributed(
        _ text: String,
        symbols: Set<String>,
        baseColor: Color
    ) -> AttributedString {
        var result = AttributedString()
        var cursor = text.startIndex
        for match in text.matches(of: /[A-Za-z_][A-Za-z0-9_]*/) {
            let name = String(text[match.range])
            guard symbols.contains(name) else { continue }
            if cursor < match.range.lowerBound {
                var plain = AttributedString(String(text[cursor..<match.range.lowerBound]))
                plain.foregroundColor = baseColor
                result += plain
            }
            var link = AttributedString(name)
            link.link = URL(string: "\(scheme):///\(name)")
            link.underlineStyle = .single
            link.foregroundColor = baseColor
            result += link
            cursor = match.range.upperBound
        }
        if cursor < text.endIndex {
            var plain = AttributedString(String(text[cursor...]))
            plain.foregroundColor = baseColor
            result += plain
        }
        return result
    }

    static func symbolName(from url: URL) -> String? {
        guard url.scheme == scheme else { return nil }
        let name = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return name.isEmpty ? nil : name
    }
}

struct DiffPaneView: View {
    let filePath: String?
    let symbolName: String?
    let focusLine: Int
    let lines: [DiffLine]
    let canJump: Bool
    let onJump: () -> Void
    var onAddNote: (() -> Void)? = nil
    var canAddNote: Bool = false
    var softWrap: Bool = true
    var callerCount: Int = 0
    var calleeCount: Int = 0
    var onJumpCallers: (() -> Void)? = nil
    var onJumpCallees: (() -> Void)? = nil
    var onShowBlast: (() -> Void)? = nil
    /// 差分内でリンク化するシンボル名（タップで onSymbolTap）。
    var linkableSymbols: Set<String> = []
    var onSymbolTap: ((String) -> Void)? = nil

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

                if callerCount + calleeCount > 0 {
                    Menu {
                        if let onJumpCallers {
                            Button("呼び出し元（\(callerCount)）") { onJumpCallers() }
                        }
                        if let onJumpCallees {
                            Button("呼び出し先（\(calleeCount)）") { onJumpCallees() }
                        }
                        if let onShowBlast {
                            Divider()
                            Button("呼び出し関係を表示") { onShowBlast() }
                        }
                    } label: {
                        Label("関係 ←\(callerCount) →\(calleeCount)", systemImage: "arrow.triangle.branch")
                            .font(Theme.caption)
                    }
                    .menuStyle(.borderlessButton)
                }

                if let onAddNote {
                    Button {
                        onAddNote()
                    } label: {
                        Image(systemName: "plus.bubble")
                    }
                    .buttonStyle(.borderless)
                    .disabled(!canAddNote)
                    .help("メモを追加")
                }

                Button {
                    onJump()
                } label: {
                    Image(systemName: "arrow.right.circle")
                }
                .buttonStyle(.borderless)
                .disabled(!canJump || filePath == nil)
                .help("IDE で開く（⇧⌘J）")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider().opacity(0.45)

            if lines.isEmpty {
                ContentUnavailableView(
                    "差分はここに表示されます",
                    systemImage: "text.alignleft",
                    description: Text("左の輪郭からシンボルを選ぶと、該当箇所の patch が開きます。\n下線付きの関数名はクリックでジャンプできます。")
                )
                .frame(maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(softWrap ? Axis.Set.vertical : [.vertical, .horizontal]) {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(lines) { line in
                                DiffLineRow(
                                    line: line,
                                    highlighted: line.newLine == focusLine,
                                    softWrap: softWrap,
                                    linkableSymbols: linkableSymbols
                                )
                                .id(line.id)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                    .onAppear { scrollToFocus(proxy) }
                    .onChange(of: focusLine) { _, _ in scrollToFocus(proxy) }
                    .onChange(of: filePath) { _, _ in scrollToFocus(proxy) }
                }
                .environment(\.openURL, OpenURLAction { url in
                    if let name = DiffSymbolLinker.symbolName(from: url) {
                        onSymbolTap?(name)
                        return .handled
                    }
                    return .systemAction
                })
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
    var softWrap: Bool = true
    var linkableSymbols: Set<String> = []

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
            Text(displayText)
                .font(Theme.monoCaption)
                .foregroundStyle(foreground)
                .tint(Theme.accent)
                .textSelection(.enabled)
                .lineLimit(softWrap ? nil : 1)
                .fixedSize(horizontal: !softWrap, vertical: false)
                .frame(maxWidth: softWrap ? .infinity : nil, alignment: .leading)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 1)
        .background(background)
    }

    /// コード行だけリンク化する（ヘッダ・メタ行は対象外）。
    private var displayText: AttributedString {
        let isCode = line.kind == .addition || line.kind == .deletion || line.kind == .context
        guard isCode, !linkableSymbols.isEmpty else {
            return AttributedString(line.text)
        }
        return DiffSymbolLinker.attributed(line.text, symbols: linkableSymbols, baseColor: foreground)
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
