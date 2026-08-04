import SwiftUI

struct ContentView: View {
    @ObservedObject var store: ReviewStore
    @ObservedObject var settings: AppSettings

    var body: some View {
        NavigationSplitView {
            PRListView(store: store, settings: settings)
                .navigationSplitViewColumnWidth(min: 260, ideal: 300, max: 380)
        } detail: {
            if store.selectedPR != nil {
                PRDetailView(store: store, settings: settings)
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
                .help("インボックスを再読み込み")
                .disabled(store.isLoading)
            }
        }
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
    }
}
