import Foundation

/// rinkaku の `gd` / `gr` に相当するジャンプ種別。
enum SymbolJumpKind: String, Sendable {
    /// 呼び出し先へ（このシンボルが呼ぶ側）
    case callees
    /// 呼び出し元へ（このシンボルを呼ぶ側）
    case callers
    /// 差分内のシンボル名タップなど、名前からの定義ジャンプ
    case symbol

    var title: String {
        switch self {
        case .callees: return "呼び出し先"
        case .callers: return "呼び出し元"
        case .symbol: return "シンボル"
        }
    }

    var statusLabel: String {
        switch self {
        case .callees: return "gd"
        case .callers: return "gr"
        case .symbol: return "jump"
        }
    }
}

/// 候補が複数あるときのピッカー状態。
struct SymbolJumpPicker: Identifiable, Sendable {
    let id: UUID
    let kind: SymbolJumpKind
    let originID: String
    let candidates: [CallGraphNode]

    init(kind: SymbolJumpKind, originID: String, candidates: [CallGraphNode]) {
        self.id = UUID()
        self.kind = kind
        self.originID = originID
        self.candidates = candidates
    }
}

/// シンボル間ジャンプの履歴（neovim jumplist 互換の簡易版）。
struct SymbolJumpList: Sendable {
    private(set) var entries: [String] = []
    private(set) var index: Int = -1

    var canGoBack: Bool { index > 0 }
    var canGoForward: Bool { index >= 0 && index < entries.count - 1 }

    /// `from` → `to` のジャンプを記録し、前方履歴を捨てる。
    mutating func recordJump(from: String?, to: String) {
        guard from != to else { return }
        if let from, entries.isEmpty {
            entries = [from]
            index = 0
        }
        if index >= 0, index < entries.count - 1 {
            entries = Array(entries.prefix(index + 1))
        }
        if entries.last != to {
            entries.append(to)
        }
        index = entries.count - 1
    }

    mutating func back() -> String? {
        guard canGoBack else { return nil }
        index -= 1
        return entries[index]
    }

    mutating func forward() -> String? {
        guard canGoForward else { return nil }
        index += 1
        return entries[index]
    }

    mutating func clear() {
        entries = []
        index = -1
    }
}
