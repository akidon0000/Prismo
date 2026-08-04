import Foundation

enum Language: String, CaseIterable, Identifiable, Sendable {
    case swift, kotlin, dart, unknown

    var id: String { rawValue }

    var label: String {
        switch self {
        case .swift: return "Swift"
        case .kotlin: return "Kotlin"
        case .dart: return "Dart"
        case .unknown: return "Other"
        }
    }

    var systemImage: String {
        switch self {
        case .swift: return "swift"
        case .kotlin: return "cup.and.saucer"
        case .dart: return "target"
        case .unknown: return "doc"
        }
    }
}

struct PullRequest: Identifiable, Hashable, Sendable {
    let id: Int
    let number: Int
    let title: String
    let repository: String
    let owner: String
    let name: String
    let author: String
    let url: URL
    let isAssignedToMe: Bool
    let language: Language
    let updatedAt: Date
    let headRef: String?
    let headSHA: String?
    let cloneURL: String
    let sshURL: String
}

/// 呼び出しグラフ上の 1 ノード（変更されたシンボル、またはその近傍）。
struct CallGraphNode: Identifiable, Hashable, Sendable {
    let id: String
    let symbolName: String
    let kind: SymbolKind
    let filePath: String
    let line: Int
    let isChanged: Bool
    /// トポロジカル順（呼び出し元が先）。小さいほど上。
    let order: Int
}

enum SymbolKind: String, Sendable {
    case function, method, type, property, other

    var label: String {
        switch self {
        case .function: return "func"
        case .method: return "method"
        case .type: return "type"
        case .property: return "prop"
        case .other: return "sym"
        }
    }
}

struct CallGraphEdge: Hashable, Sendable {
    let fromID: String
    let toID: String
}

struct CallGraph: Sendable {
    let nodes: [CallGraphNode]
    let edges: [CallGraphEdge]

    /// 呼び出し元 → 呼び出し先の順に並べたノード（ファイル名順ではない）。
    var orderedNodes: [CallGraphNode] {
        nodes.sorted { $0.order < $1.order }
    }

    /// 呼び出し順を保ったまま、ファイル単位にまとめた列。
    var fileColumns: [(filePath: String, nodes: [CallGraphNode])] {
        var seen: [String: Int] = [:]
        var columns: [(String, [CallGraphNode])] = []
        for node in orderedNodes {
            if let index = seen[node.filePath] {
                columns[index].1.append(node)
            } else {
                seen[node.filePath] = columns.count
                columns.append((node.filePath, [node]))
            }
        }
        return columns.map { (filePath: $0.0, nodes: $0.1) }
    }
}
