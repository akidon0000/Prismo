import Foundation

enum DiffLineKind: Sendable {
    case context, addition, deletion, header, meta
}

struct DiffLine: Identifiable, Sendable, Hashable {
    let id: Int
    let kind: DiffLineKind
    let text: String
    /// 新ファイル側の行番号（削除行は nil）
    let newLine: Int?
    /// 旧ファイル側の行番号（追加行は nil）
    let oldLine: Int?
}

enum DiffPatchParser {
    /// unified diff patch を表示用行に分解する。
    static func parse(_ patch: String?) -> [DiffLine] {
        guard let patch, !patch.isEmpty else { return [] }
        var lines: [DiffLine] = []
        var oldLine = 0
        var newLine = 0
        var index = 0

        for raw in patch.split(separator: "\n", omittingEmptySubsequences: false) {
            let text = String(raw)
            defer { index += 1 }

            if text.hasPrefix("@@") {
                if let (o, n) = parseHunkHeader(text) {
                    oldLine = o
                    newLine = n
                }
                lines.append(DiffLine(id: index, kind: .header, text: text, newLine: nil, oldLine: nil))
                continue
            }
            if text.hasPrefix("+++") || text.hasPrefix("---") || text.hasPrefix("diff ") || text.hasPrefix("index ") {
                lines.append(DiffLine(id: index, kind: .meta, text: text, newLine: nil, oldLine: nil))
                continue
            }
            if text.hasPrefix("+") {
                lines.append(DiffLine(id: index, kind: .addition, text: text, newLine: newLine, oldLine: nil))
                newLine += 1
                continue
            }
            if text.hasPrefix("-") {
                lines.append(DiffLine(id: index, kind: .deletion, text: text, newLine: nil, oldLine: oldLine))
                oldLine += 1
                continue
            }
            // context（先頭スペース、または空）
            let display = text.hasPrefix(" ") ? text : " \(text)"
            lines.append(DiffLine(id: index, kind: .context, text: display, newLine: newLine, oldLine: oldLine))
            oldLine += 1
            newLine += 1
        }
        return lines
    }

    /// 指定行付近の hunk だけ切り出す（前後 context 付き）。
    static func focused(patch: String?, aroundLine line: Int, radius: Int = 12) -> [DiffLine] {
        let all = parse(patch)
        guard line > 0 else { return all }
        let near = all.enumerated().filter { _, item in
            if let n = item.newLine { return abs(n - line) <= radius }
            return false
        }
        guard let first = near.first?.offset, let last = near.last?.offset else {
            return all
        }
        let start = max(0, first - 2)
        let end = min(all.count - 1, last + 2)
        return Array(all[start...end])
    }

    private static func parseHunkHeader(_ text: String) -> (Int, Int)? {
        // @@ -12,3 +40,7 @@
        guard let re = try? NSRegularExpression(pattern: #"@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@"#) else {
            return nil
        }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = re.firstMatch(in: text, range: range),
              match.numberOfRanges >= 3,
              let oldR = Range(match.range(at: 1), in: text),
              let newR = Range(match.range(at: 2), in: text),
              let old = Int(text[oldR]),
              let new = Int(text[newR])
        else { return nil }
        return (old, new)
    }
}
