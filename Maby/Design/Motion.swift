import SwiftUI

/// Shared animation curves. Naming them keeps the whole app moving with the same
/// personality instead of every view inventing its own spring.
enum Motion {
    /// The default for anything the user directly caused.
    static let snappy = Animation.spring(response: 0.34, dampingFraction: 0.78)
    /// Slightly looser, for content arriving on screen.
    static let arrive = Animation.spring(response: 0.5, dampingFraction: 0.82)
    /// Playful overshoot, reserved for celebrations.
    static let bouncy = Animation.spring(response: 0.42, dampingFraction: 0.58)
    /// Long, calm drift used by ambient backgrounds.
    static let drift = Animation.easeInOut(duration: 9).repeatForever(autoreverses: true)

    /// Staggers a list so items cascade instead of popping in together.
    static func stagger(_ index: Int, base: Double = 0.04) -> Animation {
        arrive.delay(Double(index) * base)
    }
}

/// A press effect that makes any tappable glass surface feel physical.
struct PressableStyle: ButtonStyle {
    var scale: CGFloat = 0.96

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(Motion.snappy, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableStyle {
    static var pressable: PressableStyle { PressableStyle() }
}

// MARK: - Entrance transition

extension AnyTransition {
    /// Content rises into place while fading in — the app's house transition.
    static var rise: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.96, anchor: .bottom)),
            removal: .opacity.combined(with: .scale(scale: 0.98))
        )
    }
}
