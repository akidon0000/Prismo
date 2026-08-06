import SwiftUI

struct ContentView: View {
    @ObservedObject var store: ReviewStore
    @ObservedObject var settings: AppSettings

    var body: some View {
        NavigationSplitView {
            PRListView(store: store, settings: settings)
                .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 400)
        } detail: {
            if store.selectedPR != nil {
                PRDetailView(store: store, settings: settings)
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

                Button {
                    store.loadInbox(settings: settings)
                } label: {
                    Label("更新", systemImage: "arrow.clockwise")
                }
                .help("インボックスを再読み込み（⌘R）")
                .disabled(store.isLoading)
            }
        }
        .onAppear {
            if store.pullRequests.isEmpty {
                store.loadInbox(settings: settings)
            }
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
    }
}
