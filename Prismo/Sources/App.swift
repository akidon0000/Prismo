import SwiftUI

@main
struct PrismoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = ReviewStore()
    @ObservedObject private var settings = AppSettings.shared

    var body: some Scene {
        WindowGroup {
            ContentView(store: store, settings: settings)
                .frame(minWidth: 960, minHeight: 640)
        }
        .defaultSize(width: 1200, height: 800)
        .commands {
            CommandMenu("Review") {
                Button("インボックスを更新") {
                    NotificationCenter.default.post(name: .prismoRefreshInbox, object: nil)
                }
                .keyboardShortcut("r", modifiers: [.command])

                Divider()

                Button("次のシンボル") {
                    NotificationCenter.default.post(name: .prismoNextSymbol, object: nil)
                }
                .keyboardShortcut("j", modifiers: [.command])

                Button("前のシンボル") {
                    NotificationCenter.default.post(name: .prismoPreviousSymbol, object: nil)
                }
                .keyboardShortcut("k", modifiers: [.command])
            }
        }

        Settings {
            SettingsView(settings: settings)
        }
    }
}

extension Notification.Name {
    static let prismoRefreshInbox = Notification.Name("prismo.refreshInbox")
    static let prismoNextSymbol = Notification.Name("prismo.nextSymbol")
    static let prismoPreviousSymbol = Notification.Name("prismo.previousSymbol")
}
