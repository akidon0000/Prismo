import SwiftUI
import AppKit

@main
struct PrismoApp: App {
    @StateObject private var store = ReviewStore()
    @ObservedObject private var settings = AppSettings.shared

    var body: some Scene {
        WindowGroup {
            ContentView(store: store, settings: settings)
                .frame(minWidth: 960, minHeight: 640)
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
        }

        Settings {
            SettingsView(settings: settings)
        }
    }
}
