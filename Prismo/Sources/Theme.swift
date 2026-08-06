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
    static let groupedFill = Color(nsColor: .controlBackgroundColor)

    static var title: Font { .title3.weight(.semibold) }
    static var headline: Font { .headline }
    static var body: Font { .body }
    static var callout: Font { .callout }
    static var caption: Font { .caption }
    static var caption2: Font { .caption2 }

    static var mono: Font { .system(.body, design: .monospaced) }
    static var monoCaption: Font { .system(.caption, design: .monospaced) }
    static var monoCaption2: Font { .system(.caption2, design: .monospaced) }
    static var monoCallout: Font { .system(.callout, design: .monospaced) }

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

/// 互換: 旧 OutlinePane。
typealias OutlinePane = ContentPaneCompat

struct ContentPaneCompat<Content: View>: View {
    let title: String
    var focused: Bool = false
    var trailing: String? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        ContentPane(title: title, trailing: trailing, content: content)
    }
}

/// 低優先コンテンツを畳むトグル行。
struct PriorityDisclosure<Content: View>: View {
    let title: String
    let systemImage: String
    var badge: String? = nil
    @Binding var isExpanded: Bool
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: systemImage)
                        .font(.body)
                        .foregroundStyle(Theme.accent)
                        .frame(width: 20)
                    Text(title)
                        .font(Theme.callout.weight(.medium))
                        .foregroundStyle(.primary)
                    if let badge {
                        Text(badge)
                            .font(Theme.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Theme.accent.opacity(0.12)))
                            .foregroundStyle(Theme.accent)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                content()
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Theme.groupedFill.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}

enum RightPaneKind: String, CaseIterable, Identifiable {
    case diff, blast, notes

    var id: String { rawValue }

    var label: String {
        switch self {
        case .diff: return "差分"
        case .blast: return "呼び出し"
        case .notes: return "メモ"
        }
    }

    var help: String {
        switch self {
        case .diff: return "差分"
        case .blast: return "呼び出しグラフ（⇧⌘B）"
        case .notes: return "レビューメモ"
        }
    }
}
