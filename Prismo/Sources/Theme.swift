import SwiftUI
import AppKit

/// Apple HIG 寄りの視覚トークン。コードだけモノスペース、UI は SF。
enum Theme {
    /// システムのアクセントを優先（ユーザ設定の強調色に追従）。
    static let accent = Color.accentColor
    static let warning = Color.orange
    static let risk = Color.red
    static let addition = Color(red: 0.20, green: 0.62, blue: 0.35)
    static let deletion = Color(red: 0.78, green: 0.22, blue: 0.22)
    static let dim = Color.secondary.opacity(0.75)

    static let paneBackground = Color(nsColor: .textBackgroundColor)
    static let chromeBackground = Color(nsColor: .windowBackgroundColor)

    static var title: Font { .title3.weight(.semibold) }
    static var body: Font { .body }
    static var callout: Font { .callout }
    static var caption: Font { .caption }
    static var caption2: Font { .caption2 }

    static var monoCaption: Font { .system(.caption, design: .monospaced) }
    static var monoCaption2: Font { .system(.caption2, design: .monospaced) }

    static let highFanInThreshold = 2
    static let corner: CGFloat = 10
    static let tightCorner: CGFloat = 6
}

/// プライマリ領域用の静かなパネル。
struct ContentPane<Content: View>: View {
    let title: String
    var symbol: String? = nil
    var trailing: String? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Text(title)
                    .font(Theme.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                if let trailing {
                    Text(trailing)
                        .font(Theme.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)

            Divider().opacity(0.5)
            content()
        }
        .background(Theme.paneBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}
