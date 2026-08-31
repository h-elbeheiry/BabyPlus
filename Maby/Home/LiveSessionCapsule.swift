import MabyKit
import SwiftUI

/// The floating pill that shows a nursing or sleep session in progress.
///
/// It is deliberately the loudest thing on the screen while it is up: a running
/// timer that you forget to stop is worse than no timer at all.
struct LiveSessionCapsule: View {
    let session: LiveSessionTimer.Session
    let elapsed: TimeInterval
    let onStop: () -> Void
    let onCancel: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(session.style.tint.opacity(0.28))
                    .frame(width: 30, height: 30)
                    .scaleEffect(pulse ? 1.35 : 1)
                    .opacity(pulse ? 0 : 1)
                Circle()
                    .fill(session.style.tint)
                    .frame(width: 11, height: 11)
            }
            .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 1) {
                Text(session.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Palette.inkSoft)
                Text(elapsed.clockString)
                    .font(.title3.monospacedDigit().weight(.semibold))
                    .foregroundStyle(Palette.ink)
                    .contentTransition(.numericText())
            }

            Spacer(minLength: 6)

            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Palette.inkSoft)
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.pressable)
            .accessibilityLabel("Discard this session")

            Button(action: onStop) {
                HStack(spacing: 6) {
                    Image(systemName: "stop.fill")
                    Text("Stop").fontWeight(.semibold)
                }
                .font(.subheadline)
            }
            .glassButtonStyle(prominent: true, tint: session.style.tint)
            .accessibilityLabel("Stop and save this session")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .liquidGlass(.tinted(session.style.tint.opacity(0.5)), in: Capsule())
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) { pulse = true }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Session running, \(elapsed.compactDuration)")
    }
}

#if DEBUG
#Preview {
    ZStack {
        AuroraBackground()
        LiveSessionCapsule(session: .nursing(.left), elapsed: 754, onStop: {}, onCancel: {})
            .padding()
    }
}
#endif
