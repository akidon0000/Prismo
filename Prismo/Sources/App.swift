import SwiftUI
import AppKit

@main
struct PrismoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = ReviewStore()
    @ObservedObject private var settings = AppSettings.shared

    var body: some Scene {
        WindowGroup {
            ContentView(store: store, settings: settings)
                .frame(minWidth: 960, minHeight: 640)
                .focusedSceneValue(\.prismoStore, store)
                .focusedSceneValue(\.prismoSettings, settings)
        }
        .defaultSize(width: 1200, height: 800)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("Prismo について") {
                    NSApp.orderFrontStandardAboutPanel(
                        options: [
                            .applicationName: "Prismo",
                            .credits: NSAttributedString(
                                string: "See the shape of a PR before you read it."
                            ),
                        ]
                    )
                }
            }

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

                Button("IDE へジャンプ") {
                    NotificationCenter.default.post(name: .prismoJump, object: nil)
                }
                .keyboardShortcut("j", modifiers: [.command, .shift])

                Button("メモを追加…") {
                    NotificationCenter.default.post(name: .prismoAddNote, object: nil)
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])

                Button("メモを Markdown コピー") {
                    NotificationCenter.default.post(name: .prismoCopyNotes, object: nil)
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])
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
    static let prismoJump = Notification.Name("prismo.jump")
    static let prismoAddNote = Notification.Name("prismo.addNote")
    static let prismoCopyNotes = Notification.Name("prismo.copyNotes")
}

private struct PrismoStoreKey: FocusedValueKey {
    typealias Value = ReviewStore
}

private struct PrismoSettingsKey: FocusedValueKey {
    typealias Value = AppSettings
}

extension FocusedValues {
    var prismoStore: ReviewStore? {
        get { self[PrismoStoreKey.self] }
        set { self[PrismoStoreKey.self] = newValue }
    }

    var prismoSettings: AppSettings? {
        get { self[PrismoSettingsKey.self] }
        set { self[PrismoSettingsKey.self] = newValue }
    }
}
