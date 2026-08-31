import SwiftUI

/// The frame that each onboarding step puts its example UI inside.
///
/// Rather than shipping static screenshots — which go stale the moment a colour
/// changes, ignore Dark Mode and Dynamic Type, and can't demonstrate a gesture —
/// every step renders the **real** view from the app inside this frame, fed with
/// sample data. What the new user sees during onboarding is exactly what they will
/// see a moment later, in their own appearance settings, at their own text size.
struct UIShowcase<Content: View>: View {
    /// A short annotation that points at whatever the step is teaching.
    var callout: String?
    var calloutIcon: String = "hand.tap.fill"
    var accent: Color = Palette.brand
    @ViewBuilder var content: () -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                // A soft spotlight so the example reads as a separate surface from
                // the page it sits on.
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [accent.opacity(0.22), .clear],
                            center: .center,
                            startRadius: 10,
                            endRadius: 220
                        )
                    )
                    .blur(radius: 12)

                content()
                    .padding(18)
                    .liquidGlass(.regular, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .strokeBorder(.white.opacity(0.18), lineWidth: 1)
                    }
                    .scaleEffect(appeared ? 1 : 0.94)
                    .opacity(appeared ? 1 : 0)
            }
            .frame(maxWidth: .infinity)

            if let callout {
                Label(callout, systemImage: calloutIcon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(accent.opacity(0.14), in: Capsule())
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 8)
            }
        }
        .onAppear {
            withAnimation(reduceMotion ? .easeOut(duration: 0.2) : Motion.arrive.delay(0.1)) {
                appeared = true
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Example of the screen being described")
    }
}
