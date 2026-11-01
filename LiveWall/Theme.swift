import SwiftUI

enum Theme {
    static let background = Color(red: 0.043, green: 0.043, blue: 0.078)
    static let card = Color.white.opacity(0.055)
    static let stroke = Color.white.opacity(0.09)
    static let accent = Color(red: 0.62, green: 0.42, blue: 1.0)
    static let accent2 = Color(red: 1.0, green: 0.38, blue: 0.62)
    static let accent3 = Color(red: 0.35, green: 0.85, blue: 0.98)
    static let secondaryText = Color.white.opacity(0.6)

    static let gradient = LinearGradient(
        colors: [accent, accent2],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

struct AppBackground: View {
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            RadialGradient(
                colors: [Theme.accent.opacity(0.35), .clear],
                center: .topLeading,
                startRadius: 10,
                endRadius: 520
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [Theme.accent2.opacity(0.22), .clear],
                center: .bottomTrailing,
                startRadius: 10,
                endRadius: 560
            )
            .ignoresSafeArea()
        }
    }
}

struct CardModifier: ViewModifier {
    var padding: CGFloat = 18

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Theme.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Theme.stroke, lineWidth: 1)
                    )
            )
    }
}

extension View {
    func card(padding: CGFloat = 18) -> some View {
        modifier(CardModifier(padding: padding))
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var enabled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Theme.gradient)
                    .opacity(enabled ? 1 : 0.35)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct IconBadge: View {
    let systemName: String
    var colors: [Color] = [Theme.accent, Theme.accent2]

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 44, height: 44)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
            )
    }
}
