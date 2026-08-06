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
                .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 400)
        } detail: {
            if store.selectedPR != nil {
                PRDetailView(
                    store: store,
                    settings: settings,
                    showingAddNote: $showingAddNote
                )
            } else {
                ContentUnavailableView {
                    Label("プルリクエストを選択", systemImage: "arrow.triangle.branch")
                } description: {
                    Text("左の Inbox から、レビューする PR を選んでください。\n呼び出し順の輪郭から差分を読み進められます。")
                }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if store.isLoading {
                    ProgressView()
                        .controlSize(.small)
                }

                accountMenu

                if store.notesForSelectedPR.count > 0 {
                    Text("メモ \(store.notesForSelectedPR.count)")
                        .font(Theme.caption)
                        .foregroundStyle(.secondary)
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
        .onChange(of: settings.activeAccountID) { _, _ in
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
        .onReceive(NotificationCenter.default.publisher(for: .prismoJumpCallees)) { _ in
            store.jumpToCallees()
        }
        .onReceive(NotificationCenter.default.publisher(for: .prismoJumpCallers)) { _ in
            store.jumpToCallers()
        }
        .onReceive(NotificationCenter.default.publisher(for: .prismoShowBlast)) { _ in
            store.showBlastPane()
        }
        .onReceive(NotificationCenter.default.publisher(for: .prismoJumpBack)) { _ in
            store.jumpBack()
        }
        .onReceive(NotificationCenter.default.publisher(for: .prismoJumpForward)) { _ in
            store.jumpForward()
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

    @ViewBuilder
    private var accountMenu: some View {
        Menu {
            if settings.accounts.isEmpty {
                Button("gh から取り込む") {
                    _ = settings.importFromGhCLI()
                    store.loadInbox(settings: settings)
                }
            } else {
                ForEach(settings.accounts) { account in
                    Button {
                        settings.selectAccount(account.id)
                    } label: {
                        if settings.activeAccountID == account.id {
                            Label(account.displayTitle, systemImage: "checkmark")
                        } else {
                            Text(account.displayTitle)
                        }
                    }
                }
                Divider()
                Button("gh から再取り込み") {
                    _ = settings.importFromGhCLI()
                }
            }
        } label: {
            Label(settings.activeAccount?.shortTitle ?? "アカウント", systemImage: "person.crop.circle")
        }
        .help("GitHub アカウントを切り替え")
    }
}
