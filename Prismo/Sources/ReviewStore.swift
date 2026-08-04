import Foundation
import Combine

/// PR 一覧と選択中 PR の呼び出しグラフを保持する。
/// 現状はデモ用フィクスチャ。GitHub API / tree-sitter 連携は後続。
@MainActor
final class ReviewStore: ObservableObject {
    @Published private(set) var pullRequests: [PullRequest] = []
    @Published var selectedPRID: Int?
    @Published private(set) var callGraph: CallGraph?
    @Published private(set) var isLoading = false
    @Published var statusMessage: String?

    var selectedPR: PullRequest? {
        pullRequests.first { $0.id == selectedPRID }
    }

    func loadInbox(preferAssignedFirst: Bool) {
        isLoading = true
        defer { isLoading = false }

        var items = Self.fixturePRs
        if preferAssignedFirst {
            items.sort {
                if $0.isAssignedToMe != $1.isAssignedToMe {
                    return $0.isAssignedToMe && !$1.isAssignedToMe
                }
                return $0.updatedAt > $1.updatedAt
            }
        } else {
            items.sort { $0.updatedAt > $1.updatedAt }
        }
        pullRequests = items
        if selectedPRID == nil {
            selectedPRID = items.first?.id
        }
        if let id = selectedPRID {
            loadCallGraph(for: id)
        }
        statusMessage = "デモデータ（GitHub 連携前）"
    }

    func select(_ pr: PullRequest) {
        selectedPRID = pr.id
        loadCallGraph(for: pr.id)
    }

    func loadCallGraph(for prID: Int) {
        callGraph = Self.fixtureGraph(for: prID)
    }

    // MARK: - Fixtures

    private static let fixturePRs: [PullRequest] = [
        PullRequest(
            id: 1,
            number: 128,
            title: "Add offline cache for review inbox",
            repository: "akidon0000/sample-ios",
            author: "alice",
            url: URL(string: "https://github.com/akidon0000/sample-ios/pull/128")!,
            isAssignedToMe: true,
            language: .swift,
            updatedAt: Date().addingTimeInterval(-3600)
        ),
        PullRequest(
            id: 2,
            number: 45,
            title: "Rewrite auth interceptor",
            repository: "akidon0000/sample-android",
            author: "bob",
            url: URL(string: "https://github.com/akidon0000/sample-android/pull/45")!,
            isAssignedToMe: true,
            language: .kotlin,
            updatedAt: Date().addingTimeInterval(-7200)
        ),
        PullRequest(
            id: 3,
            number: 9,
            title: "Animate onboarding hero",
            repository: "akidon0000/sample-flutter",
            author: "carol",
            url: URL(string: "https://github.com/akidon0000/sample-flutter/pull/9")!,
            isAssignedToMe: false,
            language: .dart,
            updatedAt: Date().addingTimeInterval(-86400)
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
                    CallGraphNode(id: "d1", symbolName: "OnboardingPage.build", kind: .method,
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
                    CallGraphNode(id: "s1", symbolName: "ReviewInboxView.load", kind: .method,
                                  filePath: "Sources/Features/Inbox/ReviewInboxView.swift", line: 42,
                                  isChanged: true, order: 0),
                    CallGraphNode(id: "s2", symbolName: "InboxStore.refresh", kind: .method,
                                  filePath: "Sources/Features/Inbox/InboxStore.swift", line: 18,
                                  isChanged: true, order: 1),
                    CallGraphNode(id: "s3", symbolName: "GitHubClient.fetchAssignedPRs", kind: .method,
                                  filePath: "Sources/GitHub/GitHubClient.swift", line: 77,
                                  isChanged: true, order: 2),
                    CallGraphNode(id: "s4", symbolName: "DiskCache.write", kind: .method,
                                  filePath: "Sources/Cache/DiskCache.swift", line: 55,
                                  isChanged: true, order: 3),
                    CallGraphNode(id: "s5", symbolName: "JSONCoder.encode", kind: .method,
                                  filePath: "Sources/Cache/JSONCoder.swift", line: 12,
                                  isChanged: false, order: 4),
                ],
                edges: [
                    CallGraphEdge(fromID: "s1", toID: "s2"),
                    CallGraphEdge(fromID: "s2", toID: "s3"),
                    CallGraphEdge(fromID: "s2", toID: "s4"),
                    CallGraphEdge(fromID: "s4", toID: "s5"),
                ]
            )
        }
    }
}
