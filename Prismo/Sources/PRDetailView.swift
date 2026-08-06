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

                    if store.callGraph == nil {
                        ProgressView("変更の輪郭を読み込み中…")
                            .controlSize(.small)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let graph = store.callGraph, graph.nodes.isEmpty {
                        ContentUnavailableView(
                            "表示できる変更がありません",
                            systemImage: "doc.text",
                            description: Text("このプルリクエストにはシンボルとして読み取れる差分がありません。")
                        )
                    } else if let graph = store.callGraph {
                        HSplitView {
                            OutlineTreeView(
                                graph: graph,
                                selectedNodeID: store.selectedNodeID,
                                onSelect: { store.selectNode($0) }
                            )
                            .frame(minWidth: 260)

                            DiffPaneView(
                                filePath: store.selectedNode?.filePath,
                                symbolName: store.selectedNode?.symbolName,
                                focusLine: store.selectedNode?.line ?? 1,
                                lines: store.focusedDiffLines
                            )
                            .frame(minWidth: 360)
                        }
                        .padding(12)
                    }
                }
                .background(Theme.chromeBackground)
            }
        }
    }

    @ViewBuilder
    private func header(_ pr: PullRequest) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(pr.repository)
                            .font(Theme.caption)
                            .foregroundStyle(.secondary)
                        Text("#\(pr.number)")
                            .font(Theme.caption.monospacedDigit().weight(.medium))
                            .foregroundStyle(.secondary)
                        if pr.isAssignedToMe {
                            Text("レビュー依頼")
                                .font(Theme.caption2.weight(.semibold))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Theme.accent.opacity(0.14)))
                                .foregroundStyle(Theme.accent)
                        }
                    }
                    Text(pr.title)
                        .font(Theme.title)
                        .lineLimit(2)
                }

                Spacer(minLength: 12)

                Button {
                    NSWorkspace.shared.open(pr.url)
                } label: {
                    Label("GitHubで開く", systemImage: "safari")
                }
                .buttonStyle(.bordered)
            }

            if let node = store.selectedNode {
                HStack(spacing: 12) {
                    Label(node.symbolName, systemImage: "function")
                        .font(Theme.callout.weight(.medium))
                        .lineLimit(1)
                    Text((node.filePath as NSString).lastPathComponent + ":\(node.line)")
                        .font(Theme.caption.monospaced())
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 2)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(.bar)
    }
}

/// 呼び出し順のファイル / シンボル一覧。
struct OutlineTreeView: View {
    let graph: CallGraph
    let selectedNodeID: String?
    let onSelect: (CallGraphNode) -> Void
    @State private var collapsed: Set<String> = []

    var body: some View {
        ContentPane(
            title: "変更の輪郭",
            symbol: "list.bullet.indent",
            trailing: "\(graph.fileColumns.count) ファイル"
        ) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(graph.fileColumns.enumerated()), id: \.element.filePath) { index, column in
                        fileRow(index: index, path: column.filePath, nodes: column.nodes)
                        if !collapsed.contains(column.filePath) {
                            ForEach(column.nodes) { node in
                                symbolRow(node)
                            }
                        }
                    }
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 4)
            }
        }
    }

    private func fileRow(index: Int, path: String, nodes: [CallGraphNode]) -> some View {
        let expanded = !collapsed.contains(path)
        let changed = nodes.filter(\.isChanged).count
        let fanIn = nodes.map { graph.callers(of: $0.id).count }.reduce(0, +)
        let highRisk = changed > 0 && fanIn >= Theme.highFanInThreshold
        let name = path.split(separator: "/").last.map(String.init) ?? path

        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                if collapsed.contains(path) { collapsed.remove(path) }
                else { collapsed.insert(path) }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: expanded ? "chevron.down" : "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .frame(width: 12)
                if highRisk {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(Theme.risk)
                }
                Text(name)
                    .font(Theme.callout.weight(.semibold))
                    .lineLimit(1)
                Spacer(minLength: 4)
                if changed > 0 {
                    Text("\(changed)")
                        .font(Theme.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .help("変更シンボル数")
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(path)
    }

    private func symbolRow(_ node: CallGraphNode) -> some View {
        let fanIn = graph.callers(of: node.id).count
        let highRisk = node.isChanged && fanIn >= Theme.highFanInThreshold
        let selected = node.id == selectedNodeID

        return Button {
            onSelect(node)
        } label: {
            HStack(spacing: 8) {
                Circle()
                    .fill(selected ? Theme.accent : Color.clear)
                    .frame(width: 6, height: 6)
                    .padding(.leading, 18)
                Text(node.kind.label)
                    .font(Theme.caption2.monospaced())
                    .foregroundStyle(.tertiary)
                    .frame(width: 40, alignment: .leading)
                Text(node.symbolName)
                    .font(Theme.callout.weight(selected ? .semibold : .regular))
                    .foregroundStyle(node.isChanged ? .primary : Theme.dim)
                    .lineLimit(1)
                if highRisk {
                    Image(systemName: "flame.fill")
                        .font(.caption2)
                        .foregroundStyle(Theme.warning)
                        .help("変更ありかつ呼び出し元が多い")
                }
                Spacer(minLength: 4)
                if fanIn > 0 {
                    Text("←\(fanIn)")
                        .font(Theme.caption2)
                        .foregroundStyle(.tertiary)
                }
                Text("L\(node.line)")
                    .font(Theme.caption2.monospacedDigit())
                    .foregroundStyle(.quaternary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: Theme.tightCorner, style: .continuous)
                    .fill(selected ? Theme.accent.opacity(0.12) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
