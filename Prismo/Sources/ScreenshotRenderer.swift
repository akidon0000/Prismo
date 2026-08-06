#if DEBUG
import AppKit
import SwiftUI

/// README / Site / ui-preview 用に、実 SwiftUI から PNG を焼く。
@MainActor
enum ScreenshotRenderer {
    static let settleSeconds: TimeInterval = 0.6

    enum RenderError: LocalizedError {
        case usage
        case renderFailed

        var errorDescription: String? {
            switch self {
            case .usage: return "usage: Prismo --screenshot <output.png> | --ui-preview <output-dir>"
            case .renderFailed: return "画面のレンダリングに失敗しました"
            }
        }
    }

    static func runAndExit(arguments: [String] = CommandLine.arguments) -> Never {
        do {
            guard let path = outputPath(flag: "--screenshot", arguments: arguments) else {
                throw RenderError.usage
            }
            let url = URL(fileURLWithPath: path)
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try renderInboxPNG().write(to: url)
            print("wrote \(url.path)")
            exit(0)
        } catch {
            FileHandle.standardError.write(Data((error.localizedDescription + "\n").utf8))
            exit(1)
        }
    }

    static func runAllAndExit(arguments: [String] = CommandLine.arguments) -> Never {
        do {
            guard let dirPath = outputPath(flag: "--ui-preview", arguments: arguments) else {
                throw RenderError.usage
            }
            let dir = URL(fileURLWithPath: dirPath)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            for (name, data) in try allScreens() {
                let url = dir.appendingPathComponent("\(name).png")
                try data.write(to: url)
                print("wrote \(url.path)")
            }
            exit(0)
        } catch {
            FileHandle.standardError.write(Data((error.localizedDescription + "\n").utf8))
            exit(1)
        }
    }

    nonisolated static func outputPath(flag: String, arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag) else { return nil }
        let next = arguments.index(after: index)
        guard next < arguments.endIndex, !arguments[next].hasPrefix("-") else { return nil }
        return arguments[next]
    }

    /// ui-preview で撮る画面一覧。ORDER と workflows/ui-preview.yml を同期すること。
    static func allScreens() throws -> [(name: String, data: Data)] {
        let store = fixtureStore()
        let settings = AppSettings.shared
        settings.useDemoData = true
        var showingAddNote = false
        let binding = Binding(
            get: { showingAddNote },
            set: { showingAddNote = $0 }
        )

        let inboxSize = CGSize(width: 1200, height: 800)
        let detailSize = CGSize(width: 1200, height: 800)
        let settingsSize = CGSize(width: 560, height: 620)

        return [
            ("inbox", try renderStandalone(
                ContentView(store: store, settings: settings),
                probeSize: inboxSize,
                colorScheme: .dark
            )),
            ("inbox-light", try renderStandalone(
                ContentView(store: store, settings: settings),
                probeSize: inboxSize,
                colorScheme: .light
            )),
            ("detail", try renderStandalone(
                PRDetailView(store: store, settings: settings, showingAddNote: binding),
                probeSize: detailSize,
                colorScheme: .dark
            )),
            ("settings", try renderStandalone(
                SettingsView(settings: settings),
                probeSize: settingsSize,
                colorScheme: .dark
            )),
        ]
    }

    private static func renderInboxPNG() throws -> Data {
        let store = fixtureStore()
        return try renderStandalone(
            ContentView(store: store, settings: AppSettings.shared),
            probeSize: CGSize(width: 1200, height: 800),
            colorScheme: .dark
        )
    }

    private static func fixtureStore() -> ReviewStore {
        AppSettings.shared.useDemoData = true
        let store = ReviewStore()
        store.loadDemoForPreview()
        return store
    }

    private static func renderStandalone<V: View>(
        _ rootView: V,
        probeSize: CGSize,
        colorScheme: ColorScheme
    ) throws -> Data {
        let hosting = NSHostingView(rootView:
            rootView
                .environment(\.colorScheme, colorScheme)
                .environment(\.locale, Locale(identifier: "ja_JP"))
                .frame(width: probeSize.width, height: probeSize.height)
                .background(Color(nsColor: .windowBackgroundColor))
        )
        hosting.frame = CGRect(origin: .zero, size: probeSize)
        let window = NSWindow(
            contentRect: hosting.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.appearance = NSAppearance(named: colorScheme == .dark ? .darkAqua : .aqua)
        window.contentView = hosting
        window.setFrameOrigin(NSPoint(x: -20_000, y: -20_000))
        window.orderFrontRegardless()
        hosting.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(settleSeconds))
        window.displayIfNeeded()

        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(probeSize.width * 2),
            pixelsHigh: Int(probeSize.height * 2),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            throw RenderError.renderFailed
        }
        rep.size = probeSize
        hosting.cacheDisplay(in: hosting.bounds, to: rep)
        guard let png = rep.representation(using: .png, properties: [:]) else {
            throw RenderError.renderFailed
        }
        return png
    }
}
#endif
