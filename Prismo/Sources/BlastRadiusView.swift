import SwiftUI
import AppKit

/// 選択シンボルの影響範囲 — 図（呼び出しグラフ）+ 一覧。
struct BlastRadiusView: View {
    let graph: CallGraph
    let selectedID: String?
    let onSelect: (CallGraphNode) -> Void
    var onJumpIDE: ((CallGraphNode) -> Void)? = nil
    var canJumpIDE: Bool = false
    var onCopyDiagram: (() -> Void)? = nil

    @State private var hops = 1
    @State private var showList = true

    var body: some View {
        ContentPane(
            title: "呼び出しグラフ",
            symbol: "arrow.triangle.branch",
            trailing: selectedID.flatMap { graph.node(id: $0)?.symbolName }
        ) {
            if let selectedID, let node = graph.node(id: selectedID) {
                let callers = graph.callers(of: selectedID)
                let callees = graph.callees(of: selectedID)

                VStack(spacing: 0) {
                    toolbar(node: node, callers: callers.count, callees: callees.count)

                    CallGraphDiagramView(
                        graph: graph,
                        focusID: selectedID,
                        hops: hops,
                        onSelect: onSelect
                    )
                    .frame(minHeight: 200)
                    .layoutPriority(1)

                    if showList {
                        Divider().opacity(0.4)
                        ScrollView {
                            VStack(alignment: .leading, spacing: 12) {
                                section(
                                    title: "callers  呼ばれているところ (\(callers.count))",
                                    empty: "— 呼び出し元なし —",
                                    nodes: callers,
                                    verb: "gr"
                                )
                                section(
                                    title: "callees  呼んでいるところ (\(callees.count))",
                                    empty: "— 呼び出し先なし —",
                                    nodes: callees,
                                    verb: "gd"
                                )
                            }
                            .padding(.vertical, 8)
                        }
                        .frame(maxHeight: 180)
                    }
                }
            } else {
                Text("シンボルを選択すると、どこから呼ばれているかを図で表示します")
                    .font(Theme.monoCaption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(20)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func toolbar(node: CallGraphNode, callers: Int, callees: Int) -> some View {
        HStack(spacing: 10) {
            Text("\(node.kind.label) \(node.symbolName)")
                .font(Theme.monoCaption.weight(.semibold))
                .foregroundStyle(Theme.accent)
                .lineLimit(1)

            Text("←\(callers)")
                .font(Theme.monoCaption2)
                .foregroundStyle(Theme.warning)
                .help("呼び出し元の数")
            Text("→\(callees)")
                .font(Theme.monoCaption2)
                .foregroundStyle(Theme.addition)
                .help("呼び出し先の数")

            Spacer(minLength: 4)

            Picker("hops", selection: $hops) {
                Text("1-hop").tag(1)
                Text("2-hop").tag(2)
            }
            .pickerStyle(.segmented)
            .frame(width: 120)
            .help("図に含めるホップ数")

            Toggle(isOn: $showList) {
                Text("一覧")
                    .font(Theme.caption)
            }
            .toggleStyle(.button)
            .controlSize(.small)

            if let onCopyDiagram {
                Button("図をコピー") { onCopyDiagram() }
                    .font(Theme.caption)
                    .help("この図を Mermaid でコピー")
            }

            if canJumpIDE, let onJumpIDE {
                Button("IDE") { onJumpIDE(node) }
                    .font(Theme.caption)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.03))
    }

    @ViewBuilder
    private func section(title: String, empty: String, nodes: [CallGraphNode], verb: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(Theme.monoCaption2.weight(.bold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
            if nodes.isEmpty {
                Text(empty)
                    .font(Theme.monoCaption2)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 10)
            } else {
                ForEach(nodes) { node in
                    HStack(spacing: 0) {
                        Button {
                            onSelect(node)
                        } label: {
                            HStack(spacing: 6) {
                                Text(verb)
                                    .font(Theme.monoCaption2)
                                    .foregroundStyle(Theme.accent)
                                    .frame(width: 18, alignment: .leading)
                                Text(node.isChanged ? "~" : " ")
                                    .font(Theme.monoCaption2)
                                    .foregroundStyle(Theme.warning)
                                    .frame(width: 10)
                                Text(node.kind.label)
                                    .font(Theme.monoCaption2)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 36, alignment: .leading)
                                Text(node.symbolName)
                                    .font(Theme.monoCaption)
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                                Text("\((node.filePath as NSString).lastPathComponent):\(node.line)")
                                    .font(Theme.monoCaption2)
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 3)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if canJumpIDE, let onJumpIDE {
                            Button("↗") { onJumpIDE(node) }
                                .font(Theme.monoCaption2)
                                .foregroundStyle(Theme.accent)
                                .buttonStyle(.plain)
                                .padding(.trailing, 8)
                        }
                    }
                }
            }
        }
    }
}
