import SwiftUI
import AppKit

struct PRDetailView: View {
    @ObservedObject var store: ReviewStore
    @ObservedObject var settings: AppSettings
    @Binding var showingAddNote: Bool

    var body: some View {
        Group {
            if let pr = store.selectedPR {
                VStack(spacing: 0) {
                    header(pr)
                    Divider()
                    if store.callGraph == nil {
                        ProgressView("呼び出しグラフを構築中…")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let graph = store.callGraph, graph.nodes.isEmpty {
                        ContentUnavailableView(
                            "変更ファイルなし",
                            systemImage: "doc",
                            description: Text("この PR に表示できるコード変更がありません。")
                        )
                    } else if let graph = store.callGraph {
                        HSplitView {
                            VSplitView {
                                CallGraphView(
                                    graph: graph,
                                    selectedNodeID: store.selectedNodeID,
                                    onSelect: { store.selectNode($0) }
                                )
                                .frame(minHeight: 220)

                                BlastRadiusView(
                                    graph: graph,
                                    selectedID: store.selectedNodeID,
                                    onSelect: { store.selectNode($0) }
                                )
                                .frame(minHeight: 120)
                            }
                            .frame(minWidth: 300)

                            VSplitView {
                                DiffPaneView(
                                    filePath: store.selectedNode?.filePath,
                                    symbolName: store.selectedNode?.symbolName,
                                    focusLine: store.selectedNode?.line ?? 1,
                                    lines: store.focusedDiffLines,
                                    canJump: store.canJump(settings: settings),
                                    onJump: { store.jumpToSelected(settings: settings) },
                                    onAddNote: { showingAddNote = true },
                                    canAddNote: store.selectedNode != nil
                                )
                                .frame(minHeight: 180)

                                NotesPanelView(
                                    store: store,
                                    onCopy: { store.copyNotesMarkdown() },
                                    onSubmit: {
                                        Task { await store.submitNotesToGitHub(settings: settings) }
                                    },
                                    isSubmitting: store.isSubmittingNotes,
                                    canSubmit: !pr.repository.hasPrefix("akidon0000/sample-")
                                )
                                .frame(minHeight: 120)
                            }
                            .frame(minWidth: 360)
                        }
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
                if let graph = store.callGraph {
                    Text("\(graph.nodes.count) symbols · \(graph.edges.count) edges · \(graph.fileColumns.count) files")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
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
    let selectedNodeID: String?
    let onSelect: (CallGraphNode) -> Void

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            HStack(alignment: .top, spacing: 16) {
                ForEach(Array(graph.fileColumns.enumerated()), id: \.element.filePath) { index, column in
                    FileColumnView(
                        index: index,
                        filePath: column.filePath,
                        nodes: column.nodes,
                        selectedNodeID: selectedNodeID,
                        onSelect: onSelect
                    )
                }
            }
            .padding(20)
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.35))
    }
}

private struct FileColumnView: View {
    let index: Int
    let filePath: String
    let nodes: [CallGraphNode]
    let selectedNodeID: String?
    let onSelect: (CallGraphNode) -> Void

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
                    SymbolCard(node: node, isSelected: node.id == selectedNodeID) {
                        onSelect(node)
                    }
                }
            }
        }
        .frame(width: 240, alignment: .topLeading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08))
        )
    }
}

private struct SymbolCard: View {
    let node: CallGraphNode
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
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
                    .foregroundStyle(.primary)
                Text("L\(node.line)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.18) : (node.isChanged ? Color.orange.opacity(0.08) : Color.primary.opacity(0.03)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(isSelected ? Color.accentColor.opacity(0.6) : .clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}
