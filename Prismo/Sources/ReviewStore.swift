import Foundation
import Combine

/// PR 一覧と選択中 PR の呼び出しグラフを保持する。
@MainActor
final class ReviewStore: ObservableObject {
    @Published private(set) var pullRequests: [PullRequest] = []
    @Published var selectedPRID: Int?
    @Published private(set) var callGraph: CallGraph?
    @Published private(set) var isLoading = false
    @Published private(set) var isCheckingOut = false
    @Published var statusMessage: String?
    @Published var lastError: String?

    private var loadTask: Task<Void, Never>?
    private var graphTask: Task<Void, Never>?

    var selectedPR: PullRequest? {
        pullRequests.first { $0.id == selectedPRID }
    }

    func loadInbox(settings: AppSettings) {
        loadTask?.cancel()
        loadTask = Task { await reloadInbox(settings: settings) }
    }

    func select(_ pr: PullRequest, settings: AppSettings) {
        selectedPRID = pr.id
        loadCallGraph(for: pr, settings: settings)
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
            let ide = result.openedIDE.map { " · \($0)" } ?? ""
            statusMessage = "Checkout 完了: \(result.workingDirectory.path)\(ide)"
        } catch {
            lastError = error.localizedDescription
            statusMessage = "Checkout 失敗"
        }
    }

    // MARK: - Private

    private func reloadInbox(settings: AppSettings) async {
        isLoading = true
        lastError = nil
        defer { isLoading = false }

        if settings.useDemoData {
            apply(Self.fixturePRs, preferAssignedFirst: settings.preferAssignedFirst, status: "デモデータ")
            if let pr = selectedPR {
                callGraph = Self.fixtureGraph(for: pr.id)
            }
            return
        }

        guard let token = TokenResolver.resolve(settingsToken: settings.githubToken) else {
            apply(Self.fixturePRs, preferAssignedFirst: settings.preferAssignedFirst, status: "デモデータ（トークン未設定）")
            if let pr = selectedPR {
                callGraph = Self.fixtureGraph(for: pr.id)
            }
            lastError = GitHubClientError.missingToken.localizedDescription
            return
        }

        do {
            let client = GitHubClient(token: token)
            let items = try await client.fetchInbox()
            if Task.isCancelled { return }
            if items.isEmpty {
                apply(Self.fixturePRs, preferAssignedFirst: settings.preferAssignedFirst, status: "該当 PR なし — デモを表示")
                if let pr = selectedPR { callGraph = Self.fixtureGraph(for: pr.id) }
            } else {
                apply(items, preferAssignedFirst: settings.preferAssignedFirst, status: "GitHub · \(items.count)件")
                if let pr = selectedPR {
                    loadCallGraph(for: pr, settings: settings)
                }
            }
        } catch {
            if Task.isCancelled { return }
            lastError = error.localizedDescription
            apply(Self.fixturePRs, preferAssignedFirst: settings.preferAssignedFirst, status: "デモデータ（取得失敗）")
            if let pr = selectedPR { callGraph = Self.fixtureGraph(for: pr.id) }
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
        statusMessage = status
        if selectedPRID == nil || !sorted.contains(where: { $0.id == selectedPRID }) {
            selectedPRID = sorted.first?.id
        }
    }

    private func loadCallGraph(for pr: PullRequest, settings: AppSettings) {
        graphTask?.cancel()
        callGraph = nil

        if settings.useDemoData || pr.repository.hasPrefix("akidon0000/sample-") {
            callGraph = Self.fixtureGraph(for: pr.id)
            return
        }

        graphTask = Task {
            do {
                guard let token = TokenResolver.resolve(settingsToken: settings.githubToken) else {
                    callGraph = Self.fixtureGraph(for: pr.id)
                    return
                }
                let client = GitHubClient(token: token)
                async let detail = client.fetchPullDetail(owner: pr.owner, repo: pr.name, number: pr.number)
                async let files = client.fetchPullFiles(owner: pr.owner, repo: pr.name, number: pr.number)
                let (d, f) = try await (detail, files)
                if Task.isCancelled { return }

                let enriched = enrich(pr, with: d)
                // 言語を変更ファイルから再推定
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
                callGraph = ImportCallGraphBuilder.build(from: f)
            } catch {
                if Task.isCancelled { return }
                lastError = error.localizedDescription
                callGraph = Self.fixtureGraph(for: pr.id)
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

    private static func fixtureGraph(for prID: Int) -> CallGraph {
        switch prID {
        case 2:
            return CallGraph(
                nodes: [
                    CallGraphNode(id: "k1", symbolName: "AuthInterceptor.intercept", kind: .method,
                                  filePath: "app/src/main/java/AuthInterceptor.kt", line: 12,
                                  isChanged: true, order: 0),
                    CallGraphNode(id: "k2", symbolName: "TokenStore.refresh", kind: .method,
                                  filePath: "app/src/main/java/TokenStore.kt", line: 40,
                                  isChanged: true, order: 1),
                    CallGraphNode(id: "k3", symbolName: "ApiClient.execute", kind: .method,
                                  filePath: "app/src/main/java/ApiClient.kt", line: 88,
                                  isChanged: false, order: 2),
                ],
                edges: [
                    CallGraphEdge(fromID: "k1", toID: "k2"),
                    CallGraphEdge(fromID: "k2", toID: "k3"),
                ]
            )
        case 3:
            return CallGraph(
                nodes: [
                    CallGraphNode(id: "d1", symbolName: "OnboardingPage", kind: .type,
                                  filePath: "lib/features/onboarding/onboarding_page.dart", line: 20,
                                  isChanged: true, order: 0),
                    CallGraphNode(id: "d2", symbolName: "HeroBanner", kind: .type,
                                  filePath: "lib/features/onboarding/hero_banner.dart", line: 8,
                                  isChanged: true, order: 1),
                ],
                edges: [CallGraphEdge(fromID: "d1", toID: "d2")]
            )
        default:
            return CallGraph(
                nodes: [
                    CallGraphNode(id: "s1", symbolName: "ReviewInboxView", kind: .type,
                                  filePath: "Sources/Features/Inbox/ReviewInboxView.swift", line: 42,
                                  isChanged: true, order: 0),
                    CallGraphNode(id: "s2", symbolName: "InboxStore", kind: .type,
                                  filePath: "Sources/Features/Inbox/InboxStore.swift", line: 18,
                                  isChanged: true, order: 1),
                    CallGraphNode(id: "s3", symbolName: "GitHubClient", kind: .type,
                                  filePath: "Sources/GitHub/GitHubClient.swift", line: 77,
                                  isChanged: true, order: 2),
                    CallGraphNode(id: "s4", symbolName: "DiskCache", kind: .type,
                                  filePath: "Sources/Cache/DiskCache.swift", line: 55,
                                  isChanged: true, order: 3),
                ],
                edges: [
                    CallGraphEdge(fromID: "s1", toID: "s2"),
                    CallGraphEdge(fromID: "s2", toID: "s3"),
                    CallGraphEdge(fromID: "s2", toID: "s4"),
                ]
            )
        }
    }
}
