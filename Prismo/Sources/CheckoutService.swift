import Foundation
import AppKit

enum CheckoutServiceError: LocalizedError {
    case missingHeadRef
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingHeadRef:
            return "PR の head ブランチ情報がありません"
        case .commandFailed(let message):
            return message
        }
    }
}

struct CheckoutResult: Sendable {
    let workingDirectory: URL
    let openedIDE: String?
}

enum CheckoutService {
    /// リポジトリを取得して PR ブランチを checkout し、言語に応じた IDE を開く。
    static func checkoutAndOpen(
        pr: PullRequest,
        checkoutRoot: String,
        shouldOpenIDE: Bool = true
    ) async throws -> CheckoutResult {
        guard let headRef = pr.headRef, !headRef.isEmpty else {
            throw CheckoutServiceError.missingHeadRef
        }

        let root = resolveRoot(checkoutRoot)
        let repoDir = root
            .appendingPathComponent(pr.owner)
            .appendingPathComponent(pr.name)

        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        if FileManager.default.fileExists(atPath: repoDir.path) {
            _ = try await run(in: repoDir, ["/usr/bin/git", "fetch", "origin", "+refs/pull/\(pr.number)/head:prismo/pr-\(pr.number)"])
            _ = try await run(in: repoDir, ["/usr/bin/git", "checkout", "prismo/pr-\(pr.number)"])
        } else {
            // shallow clone + fetch PR ref
            let cloneURL = pr.sshURL.isEmpty ? pr.cloneURL : pr.sshURL
            _ = try await run(
                in: root,
                ["/usr/bin/git", "clone", "--depth", "1", cloneURL, "\(pr.owner)/\(pr.name)"]
            )
            _ = try await run(in: repoDir, ["/usr/bin/git", "fetch", "origin", "+refs/pull/\(pr.number)/head:prismo/pr-\(pr.number)"])
            _ = try await run(in: repoDir, ["/usr/bin/git", "checkout", "prismo/pr-\(pr.number)"])
        }

        var opened: String?
        if shouldOpenIDE {
            opened = launchIDE(for: pr.language, at: repoDir)
        }
        return CheckoutResult(workingDirectory: repoDir, openedIDE: opened)
    }

    static func resolveRoot(_ configured: String) -> URL {
        let trimmed = configured.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return URL(fileURLWithPath: (trimmed as NSString).expandingTildeInPath)
        }
        return FileManager.default.temporaryDirectory
            .appendingPathComponent("PrismoCheckouts", isDirectory: true)
    }

    private static func launchIDE(for language: Language, at directory: URL) -> String? {
        switch language {
        case .swift:
            if let project = findFirst(in: directory, extensions: ["xcworkspace", "xcodeproj"]) {
                NSWorkspace.shared.open(project)
                return "Xcode"
            }
            if let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.dt.Xcode") {
                NSWorkspace.shared.open([directory], withApplicationAt: app, configuration: NSWorkspace.OpenConfiguration())
                return "Xcode"
            }
        case .kotlin:
            if let studio = androidStudioURL() {
                NSWorkspace.shared.open([directory], withApplicationAt: studio, configuration: NSWorkspace.OpenConfiguration())
                return "Android Studio"
            }
        case .dart:
            // Flutter は Android Studio or VS Code。Studio を優先。
            if let studio = androidStudioURL() {
                NSWorkspace.shared.open([directory], withApplicationAt: studio, configuration: NSWorkspace.OpenConfiguration())
                return "Android Studio"
            }
            if let code = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.microsoft.VSCode") {
                NSWorkspace.shared.open([directory], withApplicationAt: code, configuration: NSWorkspace.OpenConfiguration())
                return "VS Code"
            }
        case .unknown:
            NSWorkspace.shared.open(directory)
            return "Finder"
        }
        NSWorkspace.shared.open(directory)
        return "Finder"
    }

    private static func androidStudioURL() -> URL? {
        let candidates = [
            "/Applications/Android Studio.app",
            "\(NSHomeDirectory())/Applications/Android Studio.app",
        ]
        for path in candidates {
            if FileManager.default.fileExists(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.google.android.studio")
    }

    private static func findFirst(in directory: URL, extensions: [String]) -> URL? {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return nil }

        var workspace: URL?
        var project: URL?
        for case let url as URL in enumerator {
            // 深追いしすぎない
            if enumerator.level > 3 { continue }
            let ext = url.pathExtension
            if ext == "xcworkspace", workspace == nil { workspace = url }
            if ext == "xcodeproj", project == nil { project = url }
            if workspace != nil { break }
        }
        return workspace ?? project
    }

    @discardableResult
    private static func run(in directory: URL, _ args: [String]) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let process = Process()
                    process.currentDirectoryURL = directory
                    process.executableURL = URL(fileURLWithPath: args[0])
                    process.arguments = Array(args.dropFirst())
                    let out = Pipe()
                    let err = Pipe()
                    process.standardOutput = out
                    process.standardError = err
                    try process.run()
                    process.waitUntilExit()
                    let stdout = String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                    let stderr = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                    if process.terminationStatus != 0 {
                        continuation.resume(
                            throwing: CheckoutServiceError.commandFailed(
                                stderr.isEmpty ? stdout : stderr
                            )
                        )
                    } else {
                        continuation.resume(returning: stdout)
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
