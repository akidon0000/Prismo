import SwiftUI

struct ContentView: View {
    @ObservedObject var store: ReviewStore
    @ObservedObject var settings: AppSettings
    @State private var showingAddNote = false

    private var colorScheme: ColorScheme? {
        switch settings.appearance {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var body: some View {
        NavigationSplitView {
            PRListView(store: store, settings: settings)
                .navigationSplitViewColumnWidth(min: 260, ideal: 300, max: 380)
        } detail: {
            if store.selectedPR != nil {
                PRDetailView(
                    store: store,
                    settings: settings,
                    showingAddNote: $showingAddNote
                )
            } else {
                ContentUnavailableView(
                    "PR を選択",
                    systemImage: "arrow.triangle.branch",
                    description: Text("左の一覧からレビューする PR を選んでください。")
                )
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if store.isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
                if store.selectedPR != nil {
                    let count = store.notesForSelectedPR.count
                    Label("\(count)", systemImage: "note.text")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(count > 0 ? Color.primary : Color.secondary)
                        .help(count > 0 ? "下書きメモ \(count) 件" : "下書きメモなし")
                }
                if let message = store.statusMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Button {
                    store.loadInbox(settings: settings)
                } label: {
                    Label("更新", systemImage: "arrow.clockwise")
                }
                .help("インボックスを再読み込み（⌘R）")
                .disabled(store.isLoading)
            }
        }
        .preferredColorScheme(colorScheme)
        .onAppear {
            if store.pullRequests.isEmpty {
                store.loadInbox(settings: settings)
            }
        }
        .onChange(of: settings.preferAssignedFirst) { _, _ in
            store.loadInbox(settings: settings)
        }
        .onChange(of: settings.useDemoData) { _, _ in
            store.loadInbox(settings: settings)
        }
        .onChange(of: settings.githubToken) { _, _ in
            store.loadInbox(settings: settings)
        }
        .onReceive(NotificationCenter.default.publisher(for: .prismoRefreshInbox)) { _ in
            store.loadInbox(settings: settings)
        }
        .onReceive(NotificationCenter.default.publisher(for: .prismoNextSymbol)) { _ in
            store.selectAdjacentNode(delta: 1)
        }
        .onReceive(NotificationCenter.default.publisher(for: .prismoPreviousSymbol)) { _ in
            store.selectAdjacentNode(delta: -1)
        }
        .onReceive(NotificationCenter.default.publisher(for: .prismoJump)) { _ in
            store.jumpToSelected(settings: settings)
        }
        .onReceive(NotificationCenter.default.publisher(for: .prismoAddNote)) { _ in
            guard store.selectedNode != nil else { return }
            showingAddNote = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .prismoCopyNotes)) { _ in
            store.copyNotesMarkdown()
        }
        .sheet(isPresented: $showingAddNote) {
            if let node = store.selectedNode {
                AddNoteSheet(
                    symbolName: node.symbolName,
                    filePath: node.filePath,
                    line: node.line,
                    onCancel: { showingAddNote = false },
                    onSave: { text in
                        store.addNote(body: text)
                        showingAddNote = false
                    }
                )
            }
        }
    }
}
