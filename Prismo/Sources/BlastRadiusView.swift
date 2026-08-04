import SwiftUI
import AppKit

/// 選択シンボルの影響範囲（呼び出し元 / 呼び出し先）。
struct BlastRadiusView: View {
    let graph: CallGraph
    let selectedID: String?
    let onSelect: (CallGraphNode) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label("Blast radius", systemImage: "circle.circle")
                    .font(.caption.weight(.semibold))
                Spacer()
                if let selectedID, let node = graph.node(id: selectedID) {
                    Text(node.symbolName)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            Divider()

            if let selectedID {
                let callers = graph.callers(of: selectedID)
                let callees = graph.callees(of: selectedID)
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        section(title: "Callers (\(callers.count))", empty: "呼び出し元なし", nodes: callers)
                        section(title: "Callees (\(callees.count))", empty: "呼び出し先なし", nodes: callees)
                    }
                    .padding(12)
                }
            } else {
                Text("シンボルを選択すると影響範囲を表示")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.4))
    }

    @ViewBuilder
    private func section(title: String, empty: String, nodes: [CallGraphNode]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
            if nodes.isEmpty {
                Text(empty)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(nodes) { node in
                    Button {
                        onSelect(node)
                    } label: {
                        HStack(spacing: 6) {
                            Text(node.kind.label)
                                .font(.caption2.monospaced())
                                .foregroundStyle(.secondary)
                            Text(node.symbolName)
                                .font(.caption.weight(.medium))
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            Text((node.filePath as NSString).lastPathComponent)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                        .padding(6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.primary.opacity(0.04))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
