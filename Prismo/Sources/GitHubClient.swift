import Foundation

enum GitHubClientError: LocalizedError {
    case missingToken
    case http(Int, String)
    case decoding(Error)
    case invalidURL

    var errorDescription: String? {
        switch self {
        case .missingToken:
            return "GitHub トークンを解決できません。設定で PAT を入れるか、`gh auth login` を確認してください。"
        case .http(let code, let body):
            return "GitHub API エラー (\(code)): \(body.prefix(200))"
        case .decoding(let error):
            return "応答のデコードに失敗: \(error.localizedDescription)"
        case .invalidURL:
            return "不正な URL です"
        }
    }
}

struct GitHubUser: Decodable, Sendable, Hashable {
    let login: String
}

struct GitHubPullFile: Decodable, Sendable, Identifiable {
    var id: String { filename }
    let filename: String
    let status: String
    let additions: Int
    let deletions: Int
    let changes: Int
    let patch: String?
}

/// GitHub REST API（依存ゼロの URLSession、github.com のみ）。
actor GitHubClient {
    private let token: String
    private let apiBaseURL = URL(string: "https://api.github.com")!
    private let session: URLSession
    private let decoder: JSONDecoder

    init(token: String, session: URLSession = .shared) {
        self.token = token
        self.session = session
        self.decoder = JSONDecoder()
        // search API の日付は ISO8601（小数秒なし）
        self.decoder.dateDecodingStrategy = .iso8601
    }

    func viewer() async throws -> GitHubUser {
        try await get(path: "/user")
    }

    /// レビュー依頼中 + 自分が assignee / involves のオープン PR を集める。
    func fetchInbox() async throws -> [PullRequest] {
        async let reviewRequested = searchPullRequests(query: "is:pr is:open review-requested:@me")
        async let assigned = searchPullRequests(query: "is:pr is:open assignee:@me")
        async let involved = searchPullRequests(query: "is:pr is:open involves:@me")
        let (reviews, assignees, involves) = try await (reviewRequested, assigned, involved)

        let reviewIDs = Set(reviews.map(\.id))
        let assigneeIDs = Set(assignees.map(\.id))

        var byID: [Int: PullRequest] = [:]
        for item in reviews + assignees + involves {
            let isMine = reviewIDs.contains(item.id) || assigneeIDs.contains(item.id)
            if let existing = byID[item.id] {
                if isMine && !existing.isAssignedToMe {
                    byID[item.id] = item.asPullRequest(isAssignedToMe: true)
                }
            } else {
                byID[item.id] = item.asPullRequest(isAssignedToMe: isMine)
            }
        }
        return byID.values.sorted { $0.updatedAt > $1.updatedAt }
    }

    func fetchPullFiles(owner: String, repo: String, number: Int) async throws -> [GitHubPullFile] {
        try await get(path: "/repos/\(owner)/\(repo)/pulls/\(number)/files?per_page=100")
    }

    // MARK: - Private

    private struct SearchResponse: Decodable {
        let items: [SearchItem]
    }

    struct SearchItem: Decodable {
        let id: Int
        let number: Int
        let title: String
        let htmlURL: String
        let updatedAt: Date
        let repositoryURL: String
        let user: GitHubUser?
        let pullRequest: PullURL?

        struct PullURL: Decodable {
            let url: String
        }

        enum CodingKeys: String, CodingKey {
            case id, number, title, user
            case htmlURL = "html_url"
            case updatedAt = "updated_at"
            case repositoryURL = "repository_url"
            case pullRequest = "pull_request"
        }

        func asPullRequest(isAssignedToMe: Bool) -> PullRequest {
            let parts = repositoryURL.split(separator: "/").map(String.init)
            let owner = parts.count >= 2 ? parts[parts.count - 2] : ""
            let name = parts.last ?? ""
            let repoFull = "\(owner)/\(name)"
            return PullRequest(
                id: id,
                number: number,
                title: title,
                repository: repoFull,
                owner: owner,
                name: name,
                author: user?.login ?? "unknown",
                url: URL(string: htmlURL)!,
                isAssignedToMe: isAssignedToMe,
                language: Language.infer(fromRepository: repoFull, title: title),
                updatedAt: updatedAt
            )
        }
    }

    private func searchPullRequests(query: String) async throws -> [SearchItem] {
        var components = URLComponents(url: apiURL(path: "/search/issues"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "sort", value: "updated"),
            URLQueryItem(name: "order", value: "desc"),
            URLQueryItem(name: "per_page", value: "50"),
        ]
        guard let url = components.url else { throw GitHubClientError.invalidURL }
        let response: SearchResponse = try await send(url: url, method: "GET")
        return response.items.filter { $0.pullRequest != nil }
    }

    private func get<T: Decodable>(path: String) async throws -> T {
        try await send(url: apiURL(path: path), method: "GET")
    }

    private func apiURL(path: String) -> URL {
        let trimmed = path.hasPrefix("/") ? path : "/\(path)"
        return URL(string: apiBaseURL.absoluteString + trimmed)!
    }

    private func send<T: Decodable>(url: URL, method: String) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("PrismoMacOS", forHTTPHeaderField: "User-Agent")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")

        let (data, response) = try await session.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(code) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw GitHubClientError.http(code, body)
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw GitHubClientError.decoding(error)
        }
    }
}

extension Language {
    static func infer(fromRepository repository: String, title: String) -> Language {
        let haystack = (repository + " " + title).lowercased()
        if haystack.contains("android") || haystack.contains("kotlin") { return .kotlin }
        if haystack.contains("flutter") || haystack.contains("dart") { return .dart }
        if haystack.contains("ios") || haystack.contains("swift") || haystack.contains("macos") {
            return .swift
        }
        return .unknown
    }

    static func infer(fromFilePath path: String) -> Language {
        let lower = path.lowercased()
        if lower.hasSuffix(".swift") { return .swift }
        if lower.hasSuffix(".kt") || lower.hasSuffix(".kts") { return .kotlin }
        if lower.hasSuffix(".dart") { return .dart }
        return .unknown
    }
}
