import Foundation
import Combine

/// PR 一覧と選択中 PR の呼び出しグラフを保持する。
@MainActor
final class ReviewStore: ObservableObject {
    @Published private(set) var pullRequests: [PullRequest] = []
    @Published var selectedPRID: Int?
    @Published private(set) var callGraph: CallGraph?
    @Published private(set) var pullFiles: [GitHubPullFile] = []
    @Published var selectedNodeID: String?
    @Published private(set) var isLoading = false
    @Published var statusMessage: String?
    @Published var lastError: String?
    /// インボックスを最後に読み込んだ時刻。
    @Published private(set) var inboxUpdatedAt: Date?

    private var loadTask: Task<Void, Never>?
    private var graphTask: Task<Void, Never>?

    /// スクリーンショット / ui-preview 用にデモデータを同期ロードする。
    func loadDemoForPreview() {
        applyDemo(status: "デモデータ")
    }

    var selectedPR: PullRequest? {
        pullRequests.first { $0.id == selectedPRID }
    }

    var selectedNode: CallGraphNode? {
        guard let id = selectedNodeID else { return nil }
        return callGraph?.nodes.first { $0.id == id }
    }

    var selectedFilePatch: String? {
        guard let node = selectedNode else { return nil }
        return pullFiles.first { $0.filename == node.filePath }?.patch
    }

    var focusedDiffLines: [DiffLine] {
        guard let node = selectedNode else { return [] }
        return DiffPatchParser.focused(patch: selectedFilePatch, aroundLine: node.line)
    }

    func loadInbox(settings: AppSettings) {
        loadTask?.cancel()
        loadTask = Task { await reloadInbox(settings: settings) }
    }

    func select(_ pr: PullRequest, settings: AppSettings) {
        selectedPRID = pr.id
        selectedNodeID = nil
        loadCallGraph(for: pr, settings: settings)
    }

    func selectNode(_ node: CallGraphNode) {
        guard callGraph?.node(id: node.id) != nil else { return }
        selectedNodeID = node.id
    }

    /// 呼び出し順での隣接シンボルへ移動（delta: +1 次 / -1 前）。
    func selectAdjacentNode(delta: Int) {
        guard let graph = callGraph else { return }
        let ordered = graph.orderedNodes
        guard !ordered.isEmpty else { return }
        if let id = selectedNodeID, let index = ordered.firstIndex(where: { $0.id == id }) {
            let next = (index + delta + ordered.count) % ordered.count
            selectedNodeID = ordered[next].id
        } else if let first = ordered.first {
            selectedNodeID = first.id
        }
    }

    // MARK: - Private

    private func reloadInbox(settings: AppSettings) async {
        isLoading = true
        lastError = nil
        defer { isLoading = false }

        if settings.useDemoData {
            applyDemo(status: "デモデータ")
            return
        }

        guard let client = settings.makeClient() else {
            applyDemo(status: "デモデータ（トークン未設定）")
            lastError = GitHubClientError.missingToken.localizedDescription
            return
        }

        do {
            let items = try await client.fetchInbox()
            if Task.isCancelled { return }
            if items.isEmpty {
                applyDemo(status: "該当 PR なし — デモを表示")
            } else {
                apply(items, status: "GitHub · \(items.count)件")
                if let pr = selectedPR {
                    loadCallGraph(for: pr, settings: settings)
                }
            }
        } catch {
            if Task.isCancelled { return }
            lastError = error.localizedDescription
            applyDemo(status: "デモデータ（取得失敗）")
        }
    }

    private func applyDemo(status: String) {
        apply(Self.fixturePRs, status: status)
        if let pr = selectedPR {
            pullFiles = Self.fixtureFiles(for: pr.id)
            callGraph = ImportCallGraphBuilder.build(from: pullFiles)
            if selectedNodeID == nil {
                selectedNodeID = callGraph?.orderedNodes.first?.id
            }
        }
    }

    /// アサイン済みを先頭に、更新日時の新しい順で並べる。
    private func apply(_ items: [PullRequest], status: String) {
        var sorted = items
        sorted.sort {
            if $0.isAssignedToMe != $1.isAssignedToMe {
                return $0.isAssignedToMe && !$1.isAssignedToMe
            }
            return $0.updatedAt > $1.updatedAt
        }
        pullRequests = sorted
        inboxUpdatedAt = Date()
        let time = inboxUpdatedAt!.formatted(date: .omitted, time: .shortened)
        statusMessage = "\(status) · \(time)"
        if selectedPRID == nil || !sorted.contains(where: { $0.id == selectedPRID }) {
            selectedPRID = sorted.first?.id
            selectedNodeID = nil
            pullFiles = []
            callGraph = nil
        }
    }

    private func loadCallGraph(for pr: PullRequest, settings: AppSettings) {
        graphTask?.cancel()
        callGraph = nil
        pullFiles = []
        selectedNodeID = nil

        if settings.useDemoData || pr.repository.hasPrefix("akidon0000/sample-") {
            pullFiles = Self.fixtureFiles(for: pr.id)
            callGraph = ImportCallGraphBuilder.build(from: pullFiles)
            selectedNodeID = callGraph?.orderedNodes.first?.id
            return
        }

        graphTask = Task {
            do {
                guard let client = settings.makeClient() else {
                    pullFiles = Self.fixtureFiles(for: pr.id)
                    callGraph = ImportCallGraphBuilder.build(from: pullFiles)
                    selectedNodeID = callGraph?.orderedNodes.first?.id
                    return
                }
                let files = try await client.fetchPullFiles(owner: pr.owner, repo: pr.name, number: pr.number)
                if Task.isCancelled { return }
                pullFiles = files
                callGraph = ImportCallGraphBuilder.build(from: files)
                selectedNodeID = callGraph?.orderedNodes.first?.id
            } catch {
                if Task.isCancelled { return }
                lastError = error.localizedDescription
                pullFiles = Self.fixtureFiles(for: pr.id)
                callGraph = ImportCallGraphBuilder.build(from: pullFiles)
                selectedNodeID = callGraph?.orderedNodes.first?.id
            }
        }
    }

    // MARK: - Fixtures

    private static let fixturePRs: [PullRequest] = [
        PullRequest(
            id: 1, number: 128, title: "Add offline cache for review inbox",
            repository: "akidon0000/sample-ios", owner: "akidon0000", name: "sample-ios",
            author: "alice",
            url: URL(string: "https://github.com/akidon0000/sample-ios/pull/128")!,
            isAssignedToMe: true, language: .swift,
            updatedAt: Date().addingTimeInterval(-3600)
        ),
        PullRequest(
            id: 2, number: 45, title: "Rewrite auth interceptor",
            repository: "akidon0000/sample-android", owner: "akidon0000", name: "sample-android",
            author: "bob",
            url: URL(string: "https://github.com/akidon0000/sample-android/pull/45")!,
            isAssignedToMe: true, language: .kotlin,
            updatedAt: Date().addingTimeInterval(-7200)
        ),
        PullRequest(
            id: 3, number: 9, title: "Animate onboarding hero",
            repository: "akidon0000/sample-flutter", owner: "akidon0000", name: "sample-flutter",
            author: "carol",
            url: URL(string: "https://github.com/akidon0000/sample-flutter/pull/9")!,
            isAssignedToMe: false, language: .dart,
            updatedAt: Date().addingTimeInterval(-86400)
        ),
    ]

    private static func fixtureFiles(for prID: Int) -> [GitHubPullFile] {
        switch prID {
        case 2:
            return [
                GitHubPullFile(
                    filename: "app/src/main/java/AuthInterceptor.kt",
                    status: "modified", additions: 5, deletions: 1, changes: 6,
                    patch: """
                    @@ -10,3 +10,8 @@ package com.sample
                     import okhttp3.Interceptor
                    +import com.sample.TokenStore
                    +
                    +class AuthInterceptor(private val tokens: TokenStore) : Interceptor {
                    +    override fun intercept(chain: Interceptor.Chain) = chain.proceed(chain.request())
                    +}
                    """
                ),
                GitHubPullFile(
                    filename: "app/src/main/java/TokenStore.kt",
                    status: "modified", additions: 4, deletions: 0, changes: 4,
                    patch: """
                    @@ -38,0 +40,4 @@ package com.sample
                    +class TokenStore {
                    +    fun refresh() {}
                    +}
                    """
                ),
            ]
        case 3:
            return [
                GitHubPullFile(
                    filename: "lib/features/onboarding/onboarding_page.dart",
                    status: "modified", additions: 4, deletions: 0, changes: 4,
                    patch: """
                    @@ -18,0 +20,4 @@ import 'hero_banner.dart';
                    +class OnboardingPage extends StatelessWidget {
                    +  Widget build(context) => HeroBanner();
                    +}
                    """
                ),
                GitHubPullFile(
                    filename: "lib/features/onboarding/hero_banner.dart",
                    status: "added", additions: 3, deletions: 0, changes: 3,
                    patch: """
                    @@ -0,0 +1,3 @@
                    +class HeroBanner extends StatelessWidget {
                    +  Widget build(context) => const SizedBox();
                    +}
                    """
                ),
            ]
        default:
            return [
                GitHubPullFile(
                    filename: "Sources/Features/Inbox/ReviewInboxView.swift",
                    status: "modified", additions: 6, deletions: 0, changes: 6,
                    patch: """
                    @@ -40,0 +42,6 @@ import SwiftUI
                    +import InboxKit
                    +struct ReviewInboxView: View {
                    +    var body: some View { Text("inbox") }
                    +}
                    """
                ),
                GitHubPullFile(
                    filename: "Sources/Features/Inbox/InboxStore.swift",
                    status: "modified", additions: 4, deletions: 0, changes: 4,
                    patch: """
                    @@ -16,0 +18,4 @@ import Foundation
                    +final class InboxStore {
                    +    func refresh() {}
                    +}
                    """
                ),
                GitHubPullFile(
                    filename: "Sources/GitHub/GitHubClient.swift",
                    status: "modified", additions: 3, deletions: 0, changes: 3,
                    patch: """
                    @@ -75,0 +77,3 @@ import Foundation
                    +struct GitHubClient {
                    +    func fetchAssignedPRs() async {}
                    +}
                    """
                ),
                GitHubPullFile(
                    filename: "Sources/Cache/DiskCache.swift",
                    status: "modified", additions: 3, deletions: 0, changes: 3,
                    patch: """
                    @@ -53,0 +55,3 @@ import Foundation
                    +struct DiskCache {
                    +    func write() {}
                    +}
                    """
                ),
            ]
        }
    }
}
