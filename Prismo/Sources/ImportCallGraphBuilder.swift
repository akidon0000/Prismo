import Foundation

/// tree-sitter 導入前のヒューリスティック。
/// 変更ファイルの patch から import / シンボル宣言を拾い、ファイル間の呼び出し順を近似する。
enum ImportCallGraphBuilder {
    static func build(from files: [GitHubPullFile]) -> CallGraph {
        let codeFiles = files.filter { Language.infer(fromFilePath: $0.filename) != .unknown }
        let target = codeFiles.isEmpty ? files : codeFiles

        var fileImports: [String: Set<String>] = [:]
        var nodes: [CallGraphNode] = []
        var orderCounter = 0

        for file in target {
            let language = Language.infer(fromFilePath: file.filename)
            let patch = file.patch ?? ""
            let imports = extractImports(from: patch, language: language)
            fileImports[file.filename] = imports

            let symbols = extractSymbols(from: patch, language: language)
            if symbols.isEmpty {
                nodes.append(
                    CallGraphNode(
                        id: file.filename,
                        symbolName: (file.filename as NSString).lastPathComponent,
                        kind: .other,
                        filePath: file.filename,
                        line: 1,
                        isChanged: file.status != "unchanged",
                        order: orderCounter
                    )
                )
                orderCounter += 1
            } else {
                for symbol in symbols {
                    nodes.append(
                        CallGraphNode(
                            id: "\(file.filename)#\(symbol.name)#\(symbol.line)",
                            symbolName: symbol.name,
                            kind: symbol.kind,
                            filePath: file.filename,
                            line: symbol.line,
                            isChanged: true,
                            order: orderCounter
                        )
                    )
                    orderCounter += 1
                }
            }
        }

        // ファイル A が B のモジュール/ファイル名を import していれば A → B
        var edges: [CallGraphEdge] = []
        let paths = target.map(\.filename)
        for from in paths {
            let imports = fileImports[from] ?? []
            for to in paths where to != from {
                let stem = stemName(to)
                let moduleHints = moduleHints(for: to)
                if imports.contains(where: { imp in
                    let lower = imp.lowercased()
                    return lower.contains(stem.lowercased())
                        || moduleHints.contains(where: { lower.contains($0.lowercased()) })
                }) {
                    // 呼び出し元ファイルの先頭ノード → 呼び出し先ファイルの先頭ノード
                    if let fromID = nodes.first(where: { $0.filePath == from })?.id,
                       let toID = nodes.first(where: { $0.filePath == to })?.id {
                        edges.append(CallGraphEdge(fromID: fromID, toID: toID))
                    }
                }
            }
        }

        let orderedPaths = topologicalFiles(paths: paths, edges: edges, nodes: nodes)
        var remapped: [CallGraphNode] = []
        var nextOrder = 0
        for path in orderedPaths {
            for node in nodes where node.filePath == path {
                remapped.append(
                    CallGraphNode(
                        id: node.id,
                        symbolName: node.symbolName,
                        kind: node.kind,
                        filePath: node.filePath,
                        line: node.line,
                        isChanged: node.isChanged,
                        order: nextOrder
                    )
                )
                nextOrder += 1
            }
        }

        return CallGraph(nodes: remapped, edges: edges)
    }

    // MARK: - Extraction

    struct SymbolHit {
        let name: String
        let kind: SymbolKind
        let line: Int
    }

    static func extractImports(from patch: String, language: Language) -> Set<String> {
        var result: Set<String> = []
        for rawLine in patch.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)
            // diff の追加行だけ見る
            guard line.hasPrefix("+"), !line.hasPrefix("+++") else { continue }
            let content = String(line.dropFirst()).trimmingCharacters(in: .whitespaces)

            switch language {
            case .swift:
                if content.hasPrefix("import ") {
                    result.insert(content.replacingOccurrences(of: "import ", with: ""))
                }
            case .kotlin:
                if content.hasPrefix("import ") {
                    result.insert(content.replacingOccurrences(of: "import ", with: ""))
                }
            case .dart:
                if content.hasPrefix("import ") {
                    result.insert(content)
                }
            case .unknown:
                if content.hasPrefix("import ") {
                    result.insert(content)
                }
            }
        }
        return result
    }

    static func extractSymbols(from patch: String, language: Language) -> [SymbolHit] {
        var hits: [SymbolHit] = []
        var approxLine = 1
        for rawLine in patch.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)
            if line.hasPrefix("@@") {
                // @@ -a,b +c,d @@
                if let plus = line.split(separator: " ").first(where: { $0.hasPrefix("+") }) {
                    let num = plus.dropFirst().split(separator: ",").first.flatMap { Int($0) } ?? approxLine
                    approxLine = num
                }
                continue
            }
            let isAdd = line.hasPrefix("+") && !line.hasPrefix("+++")
            let isContext = line.hasPrefix(" ")
            defer {
                if isAdd || isContext || line.hasPrefix("-") && !line.hasPrefix("---") {
                    approxLine += 1
                }
            }
            guard isAdd else { continue }
            let content = String(line.dropFirst()).trimmingCharacters(in: .whitespaces)

            if let hit = matchSymbol(content, language: language, line: approxLine) {
                hits.append(hit)
            }
        }
        return hits
    }

    private static func matchSymbol(_ content: String, language: Language, line: Int) -> SymbolHit? {
        let patterns: [(NSRegularExpression, SymbolKind)] = {
            switch language {
            case .swift:
                return [
                    (regex(#"^(?:(?:public|private|internal|open|fileprivate)\s+)?(?:final\s+)?(?:class|struct|enum|actor)\s+(\w+)"#), .type),
                    (regex(#"^(?:(?:public|private|internal|open|fileprivate)\s+)?func\s+(\w+)"#), .function),
                ]
            case .kotlin:
                return [
                    (regex(#"^(?:(?:public|private|internal|protected)\s+)?(?:data\s+|sealed\s+)?(?:class|object|interface)\s+(\w+)"#), .type),
                    (regex(#"^(?:(?:public|private|internal|protected)\s+)?(?:override\s+|suspend\s+)*fun\s+(\w+)"#), .function),
                ]
            case .dart:
                return [
                    (regex(#"^(?:(?:abstract)\s+)?class\s+(\w+)"#), .type),
                    (regex(#"^(?:(?:static)\s+)?(?:[\w<>?]+\s+)?(\w+)\s*\([^;]*\)\s*\{?"#), .function),
                ]
            case .unknown:
                return []
            }
        }()

        let range = NSRange(content.startIndex..., in: content)
        for (re, kind) in patterns {
            if let match = re.firstMatch(in: content, range: range),
               match.numberOfRanges > 1,
               let nameRange = Range(match.range(at: 1), in: content) {
                let name = String(content[nameRange])
                // dart の雑マッチでキーワードを拾わない
                if ["if", "for", "while", "switch", "return", "import"].contains(name) {
                    continue
                }
                return SymbolHit(name: name, kind: kind, line: line)
            }
        }
        return nil
    }

    private static func regex(_ pattern: String) -> NSRegularExpression {
        try! NSRegularExpression(pattern: pattern)
    }

    private static func stemName(_ path: String) -> String {
        let base = (path as NSString).lastPathComponent
        return (base as NSString).deletingPathExtension
    }

    private static func moduleHints(for path: String) -> [String] {
        let parts = path.split(separator: "/").map(String.init)
        return parts.suffix(3).map { ($0 as NSString).deletingPathExtension }
    }

    /// 呼び出し元が先になるようファイルを並べる。辺が無ければパス順ではなく入力順を保つ。
    static func topologicalFiles(paths: [String], edges: [CallGraphEdge], nodes: [CallGraphNode]) -> [String] {
        let idToFile = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0.filePath) })
        var outgoing: [String: Set<String>] = [:]
        var indegree: [String: Int] = Dictionary(uniqueKeysWithValues: paths.map { ($0, 0) })

        for edge in edges {
            guard let from = idToFile[edge.fromID], let to = idToFile[edge.toID], from != to else { continue }
            if outgoing[from, default: []].insert(to).inserted {
                indegree[to, default: 0] += 1
            }
        }

        var queue = paths.filter { indegree[$0, default: 0] == 0 }
        var result: [String] = []
        var remaining = Set(paths)

        while !queue.isEmpty {
            let next = queue.removeFirst()
            guard remaining.contains(next) else { continue }
            remaining.remove(next)
            result.append(next)
            for child in outgoing[next, default: []] {
                indegree[child, default: 0] -= 1
                if indegree[child, default: 0] <= 0, remaining.contains(child) {
                    queue.append(child)
                }
            }
        }

        // サイクル残りは元の順で末尾へ
        for path in paths where remaining.contains(path) {
            result.append(path)
        }
        return result
    }
}
