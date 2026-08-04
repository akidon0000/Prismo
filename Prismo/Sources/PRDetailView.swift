import SwiftUI
import AppKit

struct PRDetailView: View {
    @ObservedObject var store: ReviewStore
    @ObservedObject var settings: AppSettings

    var body: some View {
        Group {
            if let pr = store.selectedPR {
                VStack(spacing: 0) {
                    header(pr)
                    Divider()
                    if let graph = store.callGraph {
                        if graph.nodes.isEmpty {
                            ContentUnavailableView(
                                "変更ファイルなし",
                                systemImage: "doc",
                                description: Text("この PR に表示できるコード変更がありません。")
                            )
                        } else {
                            CallGraphView(graph: graph)
                        }
                    } else {
                        ProgressView("呼び出しグラフを構築中…")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func header(_ pr: PullRequest) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(pr.repository)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("#\(pr.number)  \(pr.title)")
                    .font(.title3.weight(.semibold))
                    .lineLimit(2)
                if let head = pr.headRef {
                    Text(head)
                        .font(.caption.monospaced())
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
            if pr.isAssignedToMe {
                Label("Assigned", systemImage: "person.fill.checkmark")
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.tint.opacity(0.15), in: Capsule())
            }
            Button {
                Task { await store.checkoutSelected(settings: settings) }
            } label: {
                if store.isCheckingOut {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Label("Checkout", systemImage: "arrow.down.doc")
                }
            }
            .disabled(store.isCheckingOut || pr.repository.hasPrefix("akidon0000/sample-"))
            .help("該当ブランチを checkout して IDE を開く")

            Button {
                NSWorkspace.shared.open(pr.url)
            } label: {
                Label("GitHub", systemImage: "safari")
            }
        }
        .padding(16)
    }
}

/// ファイル名順ではなく、呼び出し順に並んだファイル列ビュー。
struct CallGraphView: View {
    let graph: CallGraph

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            HStack(alignment: .top, spacing: 16) {
                ForEach(Array(graph.fileColumns.enumerated()), id: \.element.filePath) { index, column in
                    FileColumnView(
                        index: index,
                        filePath: column.filePath,
                        nodes: column.nodes
                    )
                }
            }
            .padding(20)
        }
        .background(Color(nsColor: .textBackgroundColor))
    }
}

private struct FileColumnView: View {
    let index: Int
    let filePath: String
    let nodes: [CallGraphNode]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text("\(index + 1)")
                    .font(.caption2.monospacedDigit().weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 18, height: 18)
                    .background(Circle().fill(.tint))
                Text(filePath.split(separator: "/").last.map(String.init) ?? filePath)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
            }
            .help(filePath)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(nodes) { node in
                    SymbolCard(node: node)
                }
            }
        }
        .frame(width: 240, alignment: .topLeading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08))
        )
    }
}

private struct SymbolCard: View {
    let node: CallGraphNode

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(node.kind.label)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                Spacer()
                if node.isChanged {
                    Text("changed")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.orange)
                }
            }
            Text(node.symbolName)
                .font(.callout.weight(.medium))
                .textSelection(.enabled)
            Text("L\(node.line)")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.tertiary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(node.isChanged ? Color.orange.opacity(0.08) : Color.primary.opacity(0.03))
        )
    }
}
