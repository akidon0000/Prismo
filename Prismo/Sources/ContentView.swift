import SwiftUI

struct ContentView: View {
    @ObservedObject var store: ReviewStore
    @ObservedObject var settings: AppSettings

    var body: some View {
        NavigationSplitView {
            PRListView(store: store)
                .navigationSplitViewColumnWidth(min: 260, ideal: 300, max: 380)
        } detail: {
            if store.selectedPR != nil {
                PRDetailView(store: store)
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
                if let message = store.statusMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button {
                    store.loadInbox(preferAssignedFirst: settings.preferAssignedFirst)
                } label: {
                    Label("更新", systemImage: "arrow.clockwise")
                }
                .help("インボックスを再読み込み")
            }
        }
        .onAppear {
            if store.pullRequests.isEmpty {
                store.loadInbox(preferAssignedFirst: settings.preferAssignedFirst)
            }
        }
        .onChange(of: settings.preferAssignedFirst) { _, prefer in
            store.loadInbox(preferAssignedFirst: prefer)
        }
    }
}
