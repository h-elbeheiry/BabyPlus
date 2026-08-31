import MabyKit
import SwiftUI

/// Owns "should the paywall be on screen right now?".
///
/// Every gate in the app calls `present(for:)` and nothing else — the sheet itself
/// is attached once, at the root, so we never end up with two paywalls fighting
/// over the same window or a sheet that can't present because its parent is gone.
@MainActor
final class PaywallPresenter: ObservableObject {
    @Published var isPresented = false

    /// Which locked feature brought the person here, so the paywall can lead with
    /// the thing they actually wanted.
    @Published private(set) var highlighted: PremiumFeature?

    func present(for feature: PremiumFeature? = nil) {
        highlighted = feature
        Haptics.tap(.medium)
        isPresented = true
    }

    func dismiss() {
        isPresented = false
    }
}

// MARK: - Gating

/// Wraps a premium surface: subscribers see it, everyone else sees it *through*
/// frosted glass with an invitation on top.
///
/// Showing the real thing behind the blur is a deliberate choice — a locked screen
/// that reveals nothing is easy to dismiss, whereas a glimpse of your own data is
/// an honest argument for the upgrade.
struct PremiumGate<Content: View>: View {
    let feature: PremiumFeature
    var blurRadius: CGFloat = 14
    @ViewBuilder var content: () -> Content

    @EnvironmentObject private var subscriptions: SubscriptionService
    @EnvironmentObject private var paywall: PaywallPresenter

    var body: some View {
        if subscriptions.isUnlocked(feature) {
            content()
                .transition(.opacity)
        } else {
            content()
                .blur(radius: blurRadius)
                .saturation(0.65)
                .disabled(true)
                .accessibilityHidden(true)
                .overlay { lockOverlay }
                .clipShape(RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
        }
    }

    private var lockOverlay: some View {
        Button {
            paywall.present(for: feature)
        } label: {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Palette.gold.opacity(0.18))
                        .frame(width: 52, height: 52)
                    Image(systemName: "lock.fill")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Palette.gold)
                }

                Text(feature.title)
                    .font(.headline)
                    .foregroundStyle(Palette.ink)

                Text(feature.tagline)
                    .font(.footnote)
                    .foregroundStyle(Palette.inkSoft)

                Text("Unlock with BabyPlus+")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(
                        LinearGradient(
                            colors: [Palette.gold, Palette.gold.opacity(0.75)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: Capsule()
                    )
                    .padding(.top, 2)
            }
            .padding(22)
            .liquidGlass(.regular, in: RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
            .overlay(ShineOverlay().clipShape(RoundedRectangle(cornerRadius: Radius.large, style: .continuous)))
            .padding(20)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("\(feature.title). Unlock with BabyPlus Plus.")
    }
}

/// A compact row that advertises one Pro feature inside an otherwise free screen.
struct ProUpsellRow: View {
    let feature: PremiumFeature
    @EnvironmentObject private var paywall: PaywallPresenter

    var body: some View {
        Button {
            paywall.present(for: feature)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: feature.systemImage)
                    .font(.title3)
                    .foregroundStyle(Palette.gold)
                    .frame(width: 34)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(feature.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Palette.ink)
                        ProBadge(compact: true)
                    }
                    Text(feature.tagline)
                        .font(.caption)
                        .foregroundStyle(Palette.inkSoft)
                }

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Palette.inkSoft)
            }
            .glassCard(radius: Radius.medium, padding: 14)
        }
        .buttonStyle(.pressable)
    }
}
