import SwiftUI

/// Design tokens: paper and card surfaces, dark gray ink, one blue. The dark
/// values are derived from the light ones.
struct Theme {
    let paper: Color
    let card: Color
    let rule: Color
    let ink: Color
    let inkMuted: Color
    let inkSubtle: Color
    /// Blue for text on a surface: section labels and quiet buttons.
    let accentText: Color
    /// Blue fill for the main button, always under white text.
    let accentFill: Color
    let accentFillHover: Color
    let quietFill: Color
    let quietFillHover: Color
    let quietBorder: Color
    let shadow: Color

    static let radiusSmall: CGFloat = 8
    static let radiusLarge: CGFloat = 12

    static let light = Theme(
        paper: Color(hex: 0xF7F7F7),
        card: Color(hex: 0xFFFFFF),
        rule: Color(hex: 0xEAEAEA),
        ink: Color(hex: 0x222222),
        inkMuted: Color(hex: 0x555555),
        inkSubtle: Color(hex: 0x888888),
        accentText: Color(hex: 0x2563EB),
        accentFill: Color(hex: 0x2563EB),
        accentFillHover: Color(hex: 0x1D4ED8),
        quietFill: Color(hex: 0xEEF3FF),
        quietFillHover: Color(hex: 0xE0E9FF),
        quietBorder: Color(hex: 0xCDD9F5),
        shadow: Color.black.opacity(0.06)
    )

    static let dark = Theme(
        paper: Color(hex: 0x1C1C1E),
        card: Color(hex: 0x28282B),
        rule: Color(hex: 0x3A3A3D),
        ink: Color(hex: 0xF2F2F2),
        inkMuted: Color(hex: 0xB4B4B8),
        inkSubtle: Color(hex: 0x8C8C91),
        accentText: Color(hex: 0x8FB4FF),
        accentFill: Color(hex: 0x2563EB),
        accentFillHover: Color(hex: 0x3B74F0),
        quietFill: Color(hex: 0x1F2A44),
        quietFillHover: Color(hex: 0x27365A),
        quietBorder: Color(hex: 0x34497A),
        shadow: Color.black.opacity(0.3)
    )

    static func current(_ scheme: ColorScheme) -> Theme { scheme == .dark ? dark : light }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

/// A section label: small, bold, uppercase, blue.
struct SectionLabel: View {
    @Environment(\.colorScheme) private var scheme
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .bold))
            .tracking(0.5)
            .foregroundColor(Theme.current(scheme).accentText)
    }
}

/// The two buttons: a solid blue one and a pale blue one.
struct PanelButtonStyle: ButtonStyle {
    enum Kind { case primary, quiet }

    @Environment(\.colorScheme) private var scheme
    let kind: Kind

    func makeBody(configuration: Configuration) -> some View {
        PanelButtonBody(kind: kind, theme: Theme.current(scheme), configuration: configuration)
    }
}

private struct PanelButtonBody: View {
    let kind: PanelButtonStyle.Kind
    let theme: Theme
    let configuration: ButtonStyle.Configuration
    // Not @State: that needs a compiler plugin that ships only with Xcode,
    // and this project builds with the Command Line Tools alone.
    @StateObject private var hover = HoverState()

    var body: some View {
        let highlighted = hover.isOver || configuration.isPressed
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(kind == .primary ? .white : theme.accentText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: Theme.radiusSmall)
                    .fill(fill(highlighted: highlighted))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusSmall)
                    .strokeBorder(kind == .primary ? Color.clear : theme.quietBorder, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
            .onHover { hover.isOver = $0 }
    }

    private func fill(highlighted: Bool) -> Color {
        switch kind {
        case .primary: return highlighted ? theme.accentFillHover : theme.accentFill
        case .quiet: return highlighted ? theme.quietFillHover : theme.quietFill
        }
    }
}

private final class HoverState: ObservableObject {
    @Published var isOver = false
}
