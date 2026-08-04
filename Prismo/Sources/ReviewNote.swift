import Foundation

struct ReviewNote: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let pullRequestID: Int
    let nodeID: String
    let symbolName: String
    let filePath: String
    let line: Int
    var body: String
    let createdAt: Date

    init(
        id: UUID = UUID(),
        pullRequestID: Int,
        nodeID: String,
        symbolName: String,
        filePath: String,
        line: Int,
        body: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.pullRequestID = pullRequestID
        self.nodeID = nodeID
        self.symbolName = symbolName
        self.filePath = filePath
        self.line = line
        self.body = body
        self.createdAt = createdAt
    }
}

enum ReviewNoteExporter {
    /// AI エージェントや PR コメント用の Markdown パケット。
    static func markdown(for notes: [ReviewNote], pr: PullRequest) -> String {
        var lines: [String] = [
            "# Prismo review notes",
            "",
            "- Repo: `\(pr.repository)`",
            "- PR: [#\(pr.number)](\(pr.url.absoluteString)) — \(pr.title)",
            "",
        ]
        if notes.isEmpty {
            lines.append("_No notes._")
            return lines.joined(separator: "\n")
        }
        for (index, note) in notes.enumerated() {
            lines.append("## \(index + 1). `\(note.symbolName)`")
            lines.append("")
            lines.append("- File: `\(note.filePath):\(note.line)`")
            lines.append("")
            lines.append(note.body)
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }
}
