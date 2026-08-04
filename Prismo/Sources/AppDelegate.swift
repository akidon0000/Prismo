import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        #if DEBUG
        if CommandLine.arguments.contains("--ui-preview") {
            ScreenshotRenderer.runAllAndExit()
        }
        if CommandLine.arguments.contains("--screenshot") {
            ScreenshotRenderer.runAndExit()
        }
        #endif
    }
}
