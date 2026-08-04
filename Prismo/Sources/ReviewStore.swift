import Foundation
import Combine
import AppKit

/// PR 一覧と選択中 PR の呼び出しグラフを保持する。
@MainActor
final class ReviewStore: ObservableObject {
    @Published private(set) var pullRequests: [PullRequest] = []
    @Published var selectedPRID: Int?
    @Published private(set) var callGraph: CallGraph?
    @Published private(set) var pullFiles: [GitHubPullFile] = []
    @Published private(set) var remoteComments: [GitHubClient.GitHubReviewComment] = []
    @Published var selectedNodeID: String?
    @Published private(set) var notes: [ReviewNote] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isCheckingOut = false
    @Published private(set) var isSubmittingNotes = false
    @Published var statusMessage: String?
    @Published var lastError: String?
    /// インボックスを最後に読み込んだ時刻。
    @Published private(set) var inboxUpdatedAt: Date?
    /// PR ID → ローカル checkout パス
    @Published private(set) var checkoutPaths: [Int: String] = [:]

    private var loadTask: Task<Void, Never>?
    private var graphTask: Task<Void, Never>?

    init() {
        notes = NotesStore.load()
    }

    /// スクリーンショット / ui-preview 用にデモデータを同期ロードする。
    func loadDemoForPreview() {
        applyDemo(settings: AppSettings.shared, status: "デモデータ")
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

    var notesForSelectedPR: [ReviewNote] {
        guard let id = selectedPRID else { return [] }
        return notes.filter { $0.pullRequestID == id }
            .sorted { $0.createdAt < $1.createdAt }
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
        } else {
            selectedNodeID = ordered.first?.id
        }
    }

    func filteredPullRequests(query: String, language: Language?) -> [PullRequest] {
        pullRequests.filter { pr in
            if let language, pr.language != language { return false }
            let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !q.isEmpty else { return true }
            let haystack = "\(pr.title) \(pr.repository) \(pr.author) #\(pr.number)".lowercased()
            return haystack.contains(q.lowercased())
        }
    }

    private func persistNotes() {
        NotesStore.save(notes)
    }

    func checkoutSelected(settings: AppSettings) async {
        guard var pr = selectedPR else { return }
        isCheckingOut = true
        lastError = nil
        defer { isCheckingOut = false }

        do {
            if pr.headRef == nil {
                guard let token = TokenResolver.resolve(settingsToken: settings.githubToken) else {
                    throw GitHubClientError.missingToken
                }
                let client = GitHubClient(token: token)
                let detail = try await client.fetchPullDetail(owner: pr.owner, repo: pr.name, number: pr.number)
                pr = enrich(pr, with: detail)
                replacePR(pr)
            }

            let result = try await CheckoutService.checkoutAndOpen(
                pr: pr,
                checkoutRoot: settings.defaultCheckoutRoot,
                shouldOpenIDE: true
            )
            checkoutPaths[pr.id] = result.workingDirectory.path
            let ide = result.openedIDE.map { " · \($0)" } ?? ""
            statusMessage = "Checkout 完了: \(result.workingDirectory.path)\(ide)"
            CheckoutNotifier.notifySuccess(
                repository: pr.repository,
                path: result.workingDirectory.path
            )
        } catch {
            lastError = error.localizedDescription
            statusMessage = "Checkout 失敗"
        }
    }

    func jumpToSelected(settings: AppSettings) {
        guard let pr = selectedPR, let node = selectedNode else { return }
        lastError = nil

        let repoDir: URL
        if let path = checkoutPaths[pr.id] {
            repoDir = URL(fileURLWithPath: path)
        } else if let existing = CodeJumpService.existingCheckout(pr: pr, checkoutRoot: settings.defaultCheckoutRoot) {
            repoDir = existing
            checkoutPaths[pr.id] = existing.path
        } else {
            lastError = CodeJumpError.noCheckout.localizedDescription
            statusMessage = "Jump には Checkout が必要です"
            return
        }

        do {
            let ide = try CodeJumpService.jump(
                filePath: node.filePath,
                line: node.line,
                language: Language.infer(fromFilePath: node.filePath) == .unknown ? pr.language : Language.infer(fromFilePath: node.filePath),
                repoDirectory: repoDir
            )
            statusMessage = "Jump · \(ide) · \(node.filePath):\(node.line)"
        } catch {
            lastError = error.localizedDescription
            statusMessage = "Jump 失敗"
        }
    }

    func canJump(settings: AppSettings) -> Bool {
        guard let pr = selectedPR else { return false }
        if checkoutPaths[pr.id] != nil { return true }
        return CodeJumpService.existingCheckout(pr: pr, checkoutRoot: settings.defaultCheckoutRoot) != nil
    }

    func addNote(body: String) {
        guard let pr = selectedPR, let node = selectedNode else { return }
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        notes.append(
            ReviewNote(
                pullRequestID: pr.id,
                nodeID: node.id,
                symbolName: node.symbolName,
                filePath: node.filePath,
                line: node.line,
                body: trimmed
            )
        )
        persistNotes()
        statusMessage = "メモを追加 · \(node.symbolName)"
    }

    func deleteNote(id: UUID) {
        notes.removeAll { $0.id == id }
        persistNotes()
    }

    func copyNotesMarkdown() {
        guard let pr = selectedPR else { return }
        let md = ReviewNoteExporter.markdown(for: notesForSelectedPR, pr: pr)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(md, forType: .string)
        statusMessage = "メモを Markdown でコピーしました"
    }

    func copyCallGraphMermaid() {
        guard let graph = callGraph else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(graph.mermaidFlowchart(), forType: .string)
        statusMessage = "呼び出しグラフを Mermaid でコピーしました"
    }

    func submitNotesToGitHub(settings: AppSettings) async {
        guard var pr = selectedPR else { return }
        let batch = notesForSelectedPR
        guard !batch.isEmpty else { return }

        isSubmittingNotes = true
        lastError = nil
        defer { isSubmittingNotes = false }

        do {
            guard let token = TokenResolver.resolve(settingsToken: settings.githubToken) else {
                throw GitHubClientError.missingToken
            }
            let client = GitHubClient(token: token)
            if pr.headSHA == nil {
                let detail = try await client.fetchPullDetail(owner: pr.owner, repo: pr.name, number: pr.number)
                pr = enrich(pr, with: detail)
                replacePR(pr)
            }
            guard let sha = pr.headSHA, !sha.isEmpty else {
                throw GitHubClientError.http(400, "commit SHA を取得できませんでした")
            }

            let response = try await client.submitReviewComments(
                owner: pr.owner,
                repo: pr.name,
                number: pr.number,
                commitID: sha,
                body: "Reviewed with Prismo (\(batch.count) notes)",
                notes: batch
            )
            if let url = response.htmlURL, let link = URL(string: url) {
                NSWorkspace.shared.open(link)
            }
            statusMessage = "GitHub にレビューを投稿しました"
            // 投稿成功後はクリア（再投稿事故を防ぐ）
            notes.removeAll { $0.pullRequestID == pr.id }
            persistNotes()
        } catch {
            lastError = error.localizedDescription
            statusMessage = "レビュー投稿に失敗"
        }
    }

    // MARK: - Private

    private func reloadInbox(settings: AppSettings) async {
        isLoading = true
        lastError = nil
        defer { isLoading = false }

        if settings.useDemoData {
            applyDemo(settings: settings, status: "デモデータ")
            return
        }

        guard let token = TokenResolver.resolve(settingsToken: settings.githubToken) else {
            applyDemo(settings: settings, status: "デモデータ（トークン未設定）")
            lastError = GitHubClientError.missingToken.localizedDescription
            return
        }

        do {
            let client = GitHubClient(token: token)
            let items = try await client.fetchInbox()
            if Task.isCancelled { return }
            if items.isEmpty {
                applyDemo(settings: settings, status: "該当 PR なし — デモを表示")
            } else {
                apply(items, preferAssignedFirst: settings.preferAssignedFirst, status: "GitHub · \(items.count)件")
                if let pr = selectedPR {
                    loadCallGraph(for: pr, settings: settings)
                }
            }
        } catch {
            if Task.isCancelled { return }
            lastError = error.localizedDescription
            applyDemo(settings: settings, status: "デモデータ（取得失敗）")
        }
    }

    private func applyDemo(settings: AppSettings, status: String) {
        apply(Self.fixturePRs, preferAssignedFirst: settings.preferAssignedFirst, status: status)
        if let pr = selectedPR {
            pullFiles = Self.fixtureFiles(for: pr.id)
            remoteComments = Self.fixtureComments(for: pr.id)
            callGraph = ImportCallGraphBuilder.build(from: pullFiles)
            if selectedNodeID == nil {
                selectedNodeID = callGraph?.orderedNodes.first?.id
            }
        }
    }

    private func apply(_ items: [PullRequest], preferAssignedFirst: Bool, status: String) {
        var sorted = items
        if preferAssignedFirst {
            sorted.sort {
                if $0.isAssignedToMe != $1.isAssignedToMe {
                    return $0.isAssignedToMe && !$1.isAssignedToMe
                }
                return $0.updatedAt > $1.updatedAt
            }
        } else {
            sorted.sort { $0.updatedAt > $1.updatedAt }
        }
        pullRequests = sorted
        inboxUpdatedAt = Date()
        let time = inboxUpdatedAt!.formatted(date: .omitted, time: .shortened)
        statusMessage = "\(status) · \(time)"
        if selectedPRID == nil || !sorted.contains(where: { $0.id == selectedPRID }) {
            selectedPRID = sorted.first?.id
            selectedNodeID = nil
            pullFiles = []
            remoteComments = []
            callGraph = nil
        }
    }

    private func loadCallGraph(for pr: PullRequest, settings: AppSettings) {
        graphTask?.cancel()
        callGraph = nil
        pullFiles = []
        remoteComments = []
        selectedNodeID = nil

        if settings.useDemoData || pr.repository.hasPrefix("akidon0000/sample-") {
            pullFiles = Self.fixtureFiles(for: pr.id)
            remoteComments = Self.fixtureComments(for: pr.id)
            callGraph = ImportCallGraphBuilder.build(from: pullFiles)
            selectedNodeID = callGraph?.orderedNodes.first?.id
            return
        }

        graphTask = Task {
            do {
                guard let token = TokenResolver.resolve(settingsToken: settings.githubToken) else {
                    pullFiles = Self.fixtureFiles(for: pr.id)
                    remoteComments = Self.fixtureComments(for: pr.id)
                    callGraph = ImportCallGraphBuilder.build(from: pullFiles)
                    selectedNodeID = callGraph?.orderedNodes.first?.id
                    return
                }
                let client = GitHubClient(token: token)
                async let detail = client.fetchPullDetail(owner: pr.owner, repo: pr.name, number: pr.number)
                async let files = client.fetchPullFiles(owner: pr.owner, repo: pr.name, number: pr.number)
                async let comments = client.fetchPullReviewComments(owner: pr.owner, repo: pr.name, number: pr.number)
                let (d, f, c) = try await (detail, files, comments)
                if Task.isCancelled { return }

                let enriched = enrich(pr, with: d)
                let lang = f.compactMap { Language.infer(fromFilePath: $0.filename) }
                    .first(where: { $0 != .unknown }) ?? enriched.language
                let updated = PullRequest(
                    id: enriched.id,
                    number: enriched.number,
                    title: enriched.title,
                    repository: enriched.repository,
                    owner: enriched.owner,
                    name: enriched.name,
                    author: enriched.author,
                    url: enriched.url,
                    isAssignedToMe: enriched.isAssignedToMe,
                    language: lang,
                    updatedAt: enriched.updatedAt,
                    headRef: enriched.headRef,
                    headSHA: enriched.headSHA,
                    cloneURL: enriched.cloneURL,
                    sshURL: enriched.sshURL
                )
                replacePR(updated)
                pullFiles = f
                remoteComments = c
                callGraph = ImportCallGraphBuilder.build(from: f)
                selectedNodeID = callGraph?.orderedNodes.first?.id
            } catch {
                if Task.isCancelled { return }
                lastError = error.localizedDescription
                pullFiles = Self.fixtureFiles(for: pr.id)
                remoteComments = Self.fixtureComments(for: pr.id)
                callGraph = ImportCallGraphBuilder.build(from: pullFiles)
                selectedNodeID = callGraph?.orderedNodes.first?.id
            }
        }
    }

    private func enrich(_ pr: PullRequest, with detail: GitHubPullRequestDetail) -> PullRequest {
        let repo = detail.base.repo
        return PullRequest(
            id: pr.id,
            number: pr.number,
            title: detail.title,
            repository: repo?.fullName ?? pr.repository,
            owner: pr.owner,
            name: pr.name,
            author: detail.user.login,
            url: URL(string: detail.htmlURL) ?? pr.url,
            isAssignedToMe: pr.isAssignedToMe,
            language: pr.language,
            updatedAt: pr.updatedAt,
            headRef: detail.head.ref,
            headSHA: detail.head.sha,
            cloneURL: repo?.cloneURL ?? pr.cloneURL,
            sshURL: repo?.sshURL ?? pr.sshURL
        )
    }

    private func replacePR(_ pr: PullRequest) {
        if let index = pullRequests.firstIndex(where: { $0.id == pr.id }) {
            pullRequests[index] = pr
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
            updatedAt: Date().addingTimeInterval(-3600),
            headRef: "feature/cache", headSHA: nil,
            cloneURL: "https://github.com/akidon0000/sample-ios.git",
            sshURL: "git@github.com:akidon0000/sample-ios.git"
        ),
        PullRequest(
            id: 2, number: 45, title: "Rewrite auth interceptor",
            repository: "akidon0000/sample-android", owner: "akidon0000", name: "sample-android",
            author: "bob",
            url: URL(string: "https://github.com/akidon0000/sample-android/pull/45")!,
            isAssignedToMe: true, language: .kotlin,
            updatedAt: Date().addingTimeInterval(-7200),
            headRef: "feature/auth", headSHA: nil,
            cloneURL: "https://github.com/akidon0000/sample-android.git",
            sshURL: "git@github.com:akidon0000/sample-android.git"
        ),
        PullRequest(
            id: 3, number: 9, title: "Animate onboarding hero",
            repository: "akidon0000/sample-flutter", owner: "akidon0000", name: "sample-flutter",
            author: "carol",
            url: URL(string: "https://github.com/akidon0000/sample-flutter/pull/9")!,
            isAssignedToMe: false, language: .dart,
            updatedAt: Date().addingTimeInterval(-86400),
            headRef: "feature/hero", headSHA: nil,
            cloneURL: "https://github.com/akidon0000/sample-flutter.git",
            sshURL: "git@github.com:akidon0000/sample-flutter.git"
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

    private static func fixtureComments(for prID: Int) -> [GitHubClient.GitHubReviewComment] {
        switch prID {
        case 1:
            return [
                GitHubClient.GitHubReviewComment(
                    id: 9001,
                    path: "Sources/Features/Inbox/InboxStore.swift",
                    line: 18,
                    body: "キャッシュ無効化のタイミングも書いてほしい",
                    user: GitHubUser(login: "reviewer"),
                    htmlURL: "https://github.com/akidon0000/sample-ios/pull/128#discussion_r1"
                )
            ]
        default:
            return []
        }
    }

    /// 選択中シンボルのファイルに紐づく既存コメント。
    var remoteCommentsForSelectedFile: [GitHubClient.GitHubReviewComment] {
        guard let path = selectedNode?.filePath else { return remoteComments }
        let matched = remoteComments.filter { $0.path == path }
        return matched.isEmpty ? remoteComments : matched
    }
}
