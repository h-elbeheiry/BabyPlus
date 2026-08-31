import SwiftUI

/// The ambient backdrop the whole app sits on.
///
/// Liquid Glass only reads as glass when there is something interesting *behind*
/// it, so instead of a flat fill we drift a soft mesh of brand colors under the
/// content. It animates slowly enough to feel alive without ever competing with
/// the UI, and it honours Reduce Motion by holding still.
struct AuroraBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = 0

    /// Nudges the palette so different tabs feel subtly distinct.
    var seed: Double = 0

    private var colors: [Color] {
        [
            Palette.canvas, Palette.auroraC, Palette.canvas,
            Palette.auroraA, Palette.brandSoft, Palette.auroraB,
            Palette.canvas, Palette.auroraD, Palette.canvas
        ]
    }

    var body: some View {
        ZStack {
            Palette.canvas
            meshLayer
                .opacity(0.85)
                .blur(radius: 40)
        }
        .ignoresSafeArea()
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(Motion.drift) { phase = 1 }
        }
    }

    @ViewBuilder
    private var meshLayer: some View {
        let wobble = reduceMotion ? 0 : phase
        if #available(iOS 18.0, *) {
            MeshGradient(
                width: 3,
                height: 3,
                points: meshPoints(wobble: wobble),
                colors: colors
            )
        } else {
            // Pre-18 devices get overlapping radial gradients, which reads almost
            // identically once blurred.
            ZStack {
                RadialGradient(colors: [Palette.auroraA, .clear], center: .topLeading, startRadius: 0, endRadius: 420)
                RadialGradient(colors: [Palette.auroraB, .clear], center: .bottomTrailing, startRadius: 0, endRadius: 460)
                RadialGradient(colors: [Palette.auroraC, .clear], center: .init(x: 0.8, y: 0.25), startRadius: 0, endRadius: 380)
            }
        }
    }

    private func meshPoints(wobble: CGFloat) -> [SIMD2<Float>] {
        let drift = Float(wobble) * 0.16
        let tilt = Float(sin(seed)) * 0.06
        return [
            SIMD2(0.0, 0.0), SIMD2(0.5 + tilt, 0.0), SIMD2(1.0, 0.0),
            SIMD2(0.0, 0.5 - drift * 0.5), SIMD2(0.5 + drift, 0.5 + tilt), SIMD2(1.0, 0.5 + drift * 0.5),
            SIMD2(0.0, 1.0), SIMD2(0.5 - tilt, 1.0), SIMD2(1.0, 1.0)
        ]
    }
}

#if DEBUG
#Preview {
    AuroraBackground()
}
#endif
