import Foundation
import AppKit

enum CodeJumpError: LocalizedError {
    case fileMissing(String)
    case noCheckout

    var errorDescription: String? {
        switch self {
        case .fileMissing(let path):
            return "ファイルが見つかりません: \(path)"
        case .noCheckout:
            return "先に Checkout してください"
        }
    }
}

enum CodeJumpService {
    /// ローカル checkout 上のファイル:行を IDE で開く。
    @discardableResult
    static func jump(
        filePath: String,
        line: Int,
        language: Language,
        repoDirectory: URL
    ) throws -> String {
        let fileURL = repoDirectory.appendingPathComponent(filePath)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw CodeJumpError.fileMissing(filePath)
        }

        switch language {
        case .swift:
            if launchXed(file: fileURL, line: line) { return "Xcode" }
        case .kotlin, .dart:
            if launchAndroidStudio(file: fileURL, line: line) { return "Android Studio" }
            if launchVSCode(file: fileURL, line: line) { return "VS Code" }
        case .unknown:
            break
        }

        if launchVSCode(file: fileURL, line: line) { return "VS Code" }
        if launchXed(file: fileURL, line: line) { return "Xcode" }
        NSWorkspace.shared.open(fileURL)
        return "Finder"
    }

    static func existingCheckout(pr: PullRequest, checkoutRoot: String) -> URL? {
        let dir = CheckoutService.resolveRoot(checkoutRoot)
            .appendingPathComponent(pr.owner)
            .appendingPathComponent(pr.name)
        return FileManager.default.fileExists(atPath: dir.path) ? dir : nil
    }

    private static func launchXed(file: URL, line: Int) -> Bool {
        let xed = "/usr/bin/xed"
        guard FileManager.default.isExecutableFile(atPath: xed) else { return false }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: xed)
        process.arguments = ["-l", "\(max(line, 1))", file.path]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    private static func launchVSCode(file: URL, line: Int) -> Bool {
        let candidates = [
            "/usr/local/bin/code",
            "/opt/homebrew/bin/code",
            "\(NSHomeDirectory())/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code",
            "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code",
        ]
        guard let bin = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            return false
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: bin)
        process.arguments = ["-g", "\(file.path):\(max(line, 1))"]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    private static func launchAndroidStudio(file: URL, line: Int) -> Bool {
        let studioBins = [
            "/Applications/Android Studio.app/Contents/MacOS/studio",
            "\(NSHomeDirectory())/Applications/Android Studio.app/Contents/MacOS/studio",
        ]
        if let bin = studioBins.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: bin)
            process.arguments = ["--line", "\(max(line, 1))", file.path]
            process.standardOutput = Pipe()
            process.standardError = Pipe()
            do {
                try process.run()
                // Studio はすぐ戻らないことがあるので待たない
                return true
            } catch {
                return false
            }
        }
        if let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.google.android.studio")
            ?? (FileManager.default.fileExists(atPath: "/Applications/Android Studio.app")
                ? URL(fileURLWithPath: "/Applications/Android Studio.app") : nil) {
            NSWorkspace.shared.open([file], withApplicationAt: app, configuration: NSWorkspace.OpenConfiguration())
            return true
        }
        return false
    }
}
