import SwiftUI
import AppKit

struct PRDetailView: View {
    @ObservedObject var store: ReviewStore
    @ObservedObject var settings: AppSettings
    @Binding var showingAddNote: Bool

    @AppStorage("ui.showCallGraph") private var showCallGraph = false
    @AppStorage("ui.showNotes") private var showNotes = false

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
                        // 優先度 1: 輪郭 + 差分（常時）
                        HSplitView {
                            OutlineTreeView(
                                graph: graph,
                                selectedNodeID: store.selectedNodeID,
                                commentCounts: Dictionary(
                                    grouping: store.remoteComments.compactMap(\.path),
                                    by: { $0 }
                                ).mapValues(\.count),
                                onSelect: { store.selectNode($0) }
                            )
                            .frame(minWidth: 260)

                            DiffPaneView(
                                filePath: store.selectedNode?.filePath,
                                symbolName: store.selectedNode?.symbolName,
                                focusLine: store.selectedNode?.line ?? 1,
                                lines: store.focusedDiffLines,
                                canJump: store.canJump(settings: settings),
                                onJump: { store.jumpToSelected(settings: settings) },
                                onAddNote: { showingAddNote = true },
                                canAddNote: store.selectedNode != nil,
                                softWrap: settings.diffSoftWrap,
                                callerCount: store.callersOfSelected.count,
                                calleeCount: store.calleesOfSelected.count,
                                onJumpCallers: { store.jumpToCallers() },
                                onJumpCallees: { store.jumpToCallees() },
                                onShowBlast: {
                                    showCallGraph = true
                                    store.showBlastPane()
                                },
                                linkableSymbols: store.linkableSymbolNames,
                                onSymbolTap: { store.jumpToSymbolNamed($0) }
                            )
                            .frame(minWidth: 360)
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 10)
                        .layoutPriority(1)

                        // 優先度 2〜3: トグルで開く
                        VStack(spacing: 8) {
                            PriorityDisclosure(
                                title: "呼び出し関係",
                                systemImage: "arrow.triangle.branch",
                                badge: callRelationBadge,
                                isExpanded: $showCallGraph
                            ) {
                                BlastRadiusView(
                                    graph: graph,
                                    selectedID: store.selectedNodeID,
                                    onSelect: { store.selectNode($0) },
                                    onJumpIDE: { store.jumpToNode($0, settings: settings) },
                                    canJumpIDE: store.canJump(settings: settings),
                                    onCopyDiagram: { store.copyEgoMermaid(hops: 1) }
                                )
                                .frame(minHeight: 260)
                                .padding(8)
                            }

                            PriorityDisclosure(
                                title: "レビューメモ",
                                systemImage: "note.text",
                                badge: store.notesForSelectedPR.isEmpty
                                    ? nil
                                    : "\(store.notesForSelectedPR.count)",
                                isExpanded: $showNotes
                            ) {
                                NotesPanelView(
                                    store: store,
                                    onCopy: { store.copyNotesMarkdown() },
                                    onSubmit: {
                                        Task { await store.submitNotesToGitHub(settings: settings) }
                                    },
                                    isSubmitting: store.isSubmittingNotes,
                                    canSubmit: !pr.repository.hasPrefix("akidon0000/sample-")
                                )
                                .frame(minHeight: 200)
                                .padding(8)
                            }
                        }
                        .padding(12)
                    }
                }
                .background(Theme.chromeBackground)
                .onChange(of: store.rightPaneRequest) { _, request in
                    if request == .blast {
                        showCallGraph = true
                    } else if request == .notes {
                        showNotes = true
                    }
                    store.rightPaneRequest = nil
                }
                .sheet(item: $store.jumpPicker) { picker in
                    JumpPickerView(
                        picker: picker,
                        onChoose: { store.chooseJumpCandidate($0) },
                        onCancel: { store.cancelJumpPicker() }
                    )
                }
            }
        }
    }

    private var callRelationBadge: String? {
        let c = store.callersOfSelected.count
        let d = store.calleesOfSelected.count
        if c == 0 && d == 0 { return nil }
        return "←\(c) →\(d)"
    }

    @ViewBuilder
    private func header(_ pr: PullRequest) -> some View {
        VStack(alignment: .leading, spacing: 10) {
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

                // 優先度 1 のアクションだけ常時表示
                Button {
                    store.jumpToSelected(settings: settings)
                } label: {
                    Label("IDEで開く", systemImage: "arrow.right.circle")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!store.canJump(settings: settings) || store.selectedNode == nil)
                .help("選択中のシンボルを IDE で開く（⇧⌘J）")

                Button {
                    showingAddNote = true
                } label: {
                    Label("メモ", systemImage: "plus.bubble")
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(store.selectedNode == nil)

                // 優先度 3: その他はメニューへ
                Menu {
                    Button("呼び出し元へ", systemImage: "arrow.up.left") {
                        store.jumpToCallers()
                    }
                    .disabled(store.selectedNode == nil)
                    Button("呼び出し先へ", systemImage: "arrow.down.right") {
                        store.jumpToCallees()
                    }
                    .disabled(store.selectedNode == nil)
                    Button("呼び出し関係を表示", systemImage: "arrow.triangle.branch") {
                        showCallGraph = true
                    }
                    Divider()
                    Button("戻る", systemImage: "chevron.backward") { store.jumpBack() }
                        .disabled(!store.canJumpBack)
                    Button("進む", systemImage: "chevron.forward") { store.jumpForward() }
                        .disabled(!store.canJumpForward)
                    Divider()
                    Button("Checkout", systemImage: "arrow.down.doc") {
                        Task { await store.checkoutSelected(settings: settings) }
                    }
                    .disabled(store.isCheckingOut || pr.repository.hasPrefix("akidon0000/sample-"))
                    Button("Mermaidをコピー", systemImage: "square.on.square") {
                        store.copyCallGraphMermaid()
                    }
                    .disabled(store.callGraph?.nodes.isEmpty != false)
                    Button("URLをコピー", systemImage: "link") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(pr.url.absoluteString, forType: .string)
                        store.statusMessage = "PR URL をコピーしました"
                    }
                    Button("GitHubで開く", systemImage: "safari") {
                        NSWorkspace.shared.open(pr.url)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                }
                .menuStyle(.borderlessButton)
                .frame(width: 28)
                .help("その他の操作")
            }

            if let node = store.selectedNode {
                HStack(spacing: 12) {
                    Label(node.symbolName, systemImage: "function")
                        .font(Theme.callout.weight(.medium))
                        .lineLimit(1)
                    Text((node.filePath as NSString).lastPathComponent + ":\(node.line)")
                        .font(Theme.caption.monospaced())
                        .foregroundStyle(.secondary)
                    if store.callersOfSelected.count > 0 || store.calleesOfSelected.count > 0 {
                        Button {
                            showCallGraph = true
                        } label: {
                            Text("呼ばれ \(store.callersOfSelected.count) · 呼ぶ \(store.calleesOfSelected.count)")
                                .font(Theme.caption)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Theme.accent)
                    }
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
    var commentCounts: [String: Int] = [:]
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
        let noteCount = commentCounts[path] ?? 0
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
                if noteCount > 0 {
                    Image(systemName: "bubble.left.fill")
                        .font(.caption2)
                        .foregroundStyle(Theme.accent.opacity(0.8))
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

typealias CallGraphView = OutlineTreeView
