import Foundation

enum GitHubClientError: LocalizedError {
    case missingToken
    case http(Int, String)
    case decoding(Error)
    case invalidURL

    var errorDescription: String? {
        switch self {
        case .missingToken:
            return "GitHub トークンが未設定です。設定、または `gh auth login` を確認してください。"
        case .http(let code, let body):
            return "GitHub API エラー (\(code)): \(body.prefix(200))"
        case .decoding(let error):
            return "応答のデコードに失敗: \(error.localizedDescription)"
        case .invalidURL:
            return "不正な URL です"
        }
    }
}

struct GitHubUser: Decodable, Sendable {
    let login: String
}

struct GitHubRepo: Decodable, Sendable {
    let fullName: String
    let cloneURL: String
    let sshURL: String

    enum CodingKeys: String, CodingKey {
        case fullName = "full_name"
        case cloneURL = "clone_url"
        case sshURL = "ssh_url"
    }
}

struct GitHubRef: Decodable, Sendable {
    let ref: String
    let sha: String
    let repo: GitHubRepo?
}

struct GitHubPullRequestDetail: Decodable, Sendable {
    let number: Int
    let title: String
    let htmlURL: String
    let user: GitHubUser
    let head: GitHubRef
    let base: GitHubRef

    enum CodingKeys: String, CodingKey {
        case number, title, user, head, base
        case htmlURL = "html_url"
    }
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

/// GitHub REST API（依存ゼロの URLSession）。
actor GitHubClient {
    private let token: String
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
        let me = try await viewer().login
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

        // involves で自分の PR だけが残る場合のノイズを少し抑える: author==me かつ未アサインは末尾扱いで残す
        _ = me
        return byID.values.sorted { $0.updatedAt > $1.updatedAt }
    }

    func fetchPullDetail(owner: String, repo: String, number: Int) async throws -> GitHubPullRequestDetail {
        try await get(path: "/repos/\(owner)/\(repo)/pulls/\(number)")
    }

    func fetchPullFiles(owner: String, repo: String, number: Int) async throws -> [GitHubPullFile] {
        try await get(path: "/repos/\(owner)/\(repo)/pulls/\(number)/files?per_page=100")
    }

    /// メモをまとめて 1 件の PR レビュー（COMMENT）として投稿する。
    @discardableResult
    func submitReviewComments(
        owner: String,
        repo: String,
        number: Int,
        commitID: String,
        body: String,
        notes: [ReviewNote]
    ) async throws -> GitHubReviewResponse {
        struct Comment: Encodable {
            let path: String
            let line: Int
            let side: String
            let body: String
        }
        struct Payload: Encodable {
            let commitID: String
            let body: String
            let event: String
            let comments: [Comment]

            enum CodingKeys: String, CodingKey {
                case body, event, comments
                case commitID = "commit_id"
            }
        }

        let comments = notes.map {
            Comment(
                path: $0.filePath,
                line: max($0.line, 1),
                side: "RIGHT",
                body: "**\($0.symbolName)**\n\n\($0.body)"
            )
        }
        let payload = Payload(
            commitID: commitID,
            body: body,
            event: "COMMENT",
            comments: comments
        )
        return try await post(
            path: "/repos/\(owner)/\(repo)/pulls/\(number)/reviews",
            body: payload
        )
    }

    // MARK: - Private

    struct GitHubReviewResponse: Decodable, Sendable {
        let id: Int
        let htmlURL: String?
        enum CodingKeys: String, CodingKey {
            case id
            case htmlURL = "html_url"
        }
    }

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
            enum CodingKeys: String, CodingKey {
                case url
            }
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
                updatedAt: updatedAt,
                headRef: nil,
                headSHA: nil,
                cloneURL: "https://github.com/\(repoFull).git",
                sshURL: "git@github.com:\(repoFull).git"
            )
        }
    }

    private func searchPullRequests(query: String) async throws -> [SearchItem] {
        var components = URLComponents(string: "https://api.github.com/search/issues")!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "sort", value: "updated"),
            URLQueryItem(name: "order", value: "desc"),
            URLQueryItem(name: "per_page", value: "50"),
        ]
        let response: SearchResponse = try await send(url: components.url!, method: "GET", body: nil as Data?)
        return response.items.filter { $0.pullRequest != nil }
    }

    private func get<T: Decodable>(path: String) async throws -> T {
        guard let url = URL(string: "https://api.github.com\(path)") else {
            throw GitHubClientError.invalidURL
        }
        return try await send(url: url, method: "GET", body: nil as Data?)
    }

    private func post<Body: Encodable, T: Decodable>(path: String, body: Body) async throws -> T {
        guard let url = URL(string: "https://api.github.com\(path)") else {
            throw GitHubClientError.invalidURL
        }
        let data = try JSONEncoder().encode(body)
        return try await send(url: url, method: "POST", body: data)
    }

    private func send<T: Decodable>(url: URL, method: String, body: Data?) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("PrismoMacOS", forHTTPHeaderField: "User-Agent")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
        }

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
