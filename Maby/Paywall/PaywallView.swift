import MabyKit
import StoreKit
import SwiftUI

/// The BabyPlus+ subscription screen.
///
/// Structure is deliberately conventional — hero, value, price, one button — because
/// a paywall is the one screen where being clever costs money. The Liquid Glass
/// treatment does the delighting; the copy stays plain, and every commitment
/// (price, cadence, renewal, how to cancel) is on screen before the button is.
struct PaywallView: View {
    @EnvironmentObject private var subscriptions: SubscriptionService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The feature that sent the person here, promoted to the top of the list.
    var highlighted: PremiumFeature?

    @State private var selectedPlan: SubscriptionProduct = .yearly
    @State private var didPurchase = false
    /// Set when a purchase is approved out of band (ask-to-buy, SCA) so the
    /// celebration only fires for someone who actually just bought something.
    @State private var awaitingApproval = false
    @State private var pendingMessage: String?
    @State private var errorMessage: String?
    @Namespace private var glassNamespace

    private var orderedFeatures: [PremiumFeature] {
        guard let highlighted else { return PremiumFeature.allCases }
        return [highlighted] + PremiumFeature.allCases.filter { $0 != highlighted }
    }

    var body: some View {
        ZStack {
            AuroraBackground(seed: 1.2)

            if didPurchase {
                PurchaseCelebration { dismiss() }
                    .transition(.rise)
            } else {
                content
                    .transition(.opacity)
            }
        }
        .animation(Motion.arrive, value: didPurchase)
        .task {
            await subscriptions.loadProducts()
            await subscriptions.refreshEntitlements()
        }
        .onChange(of: subscriptions.isSubscribed) { _, isSubscribed in
            // Only celebrate a purchase this screen was waiting on — a routine
            // entitlement refresh shouldn't throw confetti at an existing
            // subscriber who opened the paywall to read the small print.
            if isSubscribed && awaitingApproval { didPurchase = true }
        }
    }

    // MARK: - Main content

    private var content: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    hero
                    featureList
                    planPicker
                    legal
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 220)
            }
            .scrollIndicators(.hidden)
            .softScrollEdges()
        }
        .safeAreaInset(edge: .bottom) { purchaseBar }
        .overlay(alignment: .topTrailing) { closeButton }
    }

    private var closeButton: some View {
        Button {
            Haptics.tap()
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.footnote.weight(.bold))
                .foregroundStyle(Palette.inkSoft)
                .frame(width: 34, height: 34)
                .liquidGlass(.interactive, in: Circle())
        }
        .buttonStyle(.pressable)
        .padding(.trailing, 18)
        .padding(.top, 8)
        .accessibilityLabel("Close")
    }

    // MARK: Hero

    private var hero: some View {
        VStack(spacing: 12) {
            PaywallGlyph()
                .frame(width: 108, height: 108)

            VStack(spacing: 6) {
                Text("BabyPlus+")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Palette.ink, Palette.brand],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                Text(highlighted?.subtitle ?? "Everything you already love, plus the parts that turn a log into an answer.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.inkSoft)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
        }
        .padding(.top, 20)
    }

    // MARK: Features

    private var featureList: some View {
        GlassStack(spacing: 16) {
            VStack(spacing: 10) {
                ForEach(Array(orderedFeatures.enumerated()), id: \.element.id) { index, feature in
                    PaywallFeatureRow(
                        feature: feature,
                        isHighlighted: feature == highlighted
                    )
                    .transition(.rise)
                    .animation(reduceMotion ? nil : Motion.stagger(index), value: highlighted)
                }
            }
        }
    }

    // MARK: Plans

    @ViewBuilder
    private var planPicker: some View {
        if subscriptions.products.isEmpty {
            PlanPlaceholder(isLoading: subscriptions.isLoadingProducts, message: subscriptions.lastErrorMessage) {
                Task { await subscriptions.loadProducts() }
            }
        } else {
            GlassStack(spacing: 14) {
                VStack(spacing: 12) {
                    ForEach(SubscriptionProduct.allCases, id: \.rawValue) { plan in
                        if let product = subscriptions.product(for: plan) {
                            PlanCard(
                                product: product,
                                plan: plan,
                                isSelected: selectedPlan == plan,
                                savingsPercent: plan == .yearly ? savingsPercent : nil,
                                introOffer: subscriptions.isEligibleForIntroOffer ? product.introductoryOfferLabel : nil
                            ) {
                                withAnimation(Motion.snappy) { selectedPlan = plan }
                                Haptics.selection()
                            }
                            .glassMorphID(plan.rawValue, in: glassNamespace)
                        }
                    }
                }
            }
        }
    }

    /// How much cheaper a year of Pro is than twelve months of it.
    private var savingsPercent: Int? {
        guard
            let monthly = subscriptions.product(for: .monthly),
            let yearly = subscriptions.product(for: .yearly),
            monthly.price > 0
        else { return nil }

        let yearlyPerMonth = yearly.price / 12
        guard yearlyPerMonth < monthly.price else { return nil }

        let ratio = (monthly.price - yearlyPerMonth) / monthly.price * 100
        let rounded = NSDecimalNumber(decimal: ratio).intValue
        return rounded > 0 ? rounded : nil
    }

    // MARK: Purchase bar

    private var purchaseBar: some View {
        VStack(spacing: 10) {
            if let pendingMessage {
                Label(pendingMessage, systemImage: "clock.fill")
                    .font(.footnote)
                    .foregroundStyle(Palette.inkSoft)
            }

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Button(action: buy) {
                HStack(spacing: 8) {
                    if subscriptions.purchasingProductID != nil {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "sparkles")
                    }
                    Text(callToAction)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
            .glassButtonStyle(prominent: true, tint: Palette.brand)
            .controlSize(.large)
            .disabled(subscriptions.products.isEmpty || subscriptions.purchasingProductID != nil)

            Text(renewalDisclosure)
                .font(.caption2)
                .foregroundStyle(Palette.inkSoft)
                .multilineTextAlignment(.center)

            Button {
                Task {
                    let restored = await subscriptions.restore()
                    if !restored {
                        errorMessage = "We couldn't find a subscription on this Apple Account."
                    }
                }
            } label: {
                if subscriptions.isRestoring {
                    ProgressView()
                } else {
                    Text("Restore purchases")
                        .font(.footnote.weight(.medium))
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(Palette.brand)
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .background(alignment: .top) {
            LinearGradient(
                colors: [Palette.canvas.opacity(0), Palette.canvas.opacity(0.9)],
                startPoint: .top,
                endPoint: .center
            )
            .allowsHitTesting(false)
            .ignoresSafeArea()
        }
    }

    private var callToAction: LocalizedStringKey {
        if subscriptions.products.isEmpty { return "Loading plans…" }
        if subscriptions.isEligibleForIntroOffer,
           let product = subscriptions.product(for: selectedPlan),
           product.introductoryOfferLabel != nil {
            return "Start free trial"
        }
        return "Continue"
    }

    private var renewalDisclosure: LocalizedStringKey {
        guard let product = subscriptions.product(for: selectedPlan) else {
            return "Cancel anytime in Settings."
        }
        return "\(product.displayPrice) per \(product.periodLabel), renews automatically until cancelled. Cancel anytime in Settings."
    }

    private func buy() {
        guard let product = subscriptions.product(for: selectedPlan) else { return }
        errorMessage = nil
        pendingMessage = nil

        Task {
            switch await subscriptions.purchase(product) {
            case .success:
                Haptics.success()
                didPurchase = true
            case .pending:
                awaitingApproval = true
                pendingMessage = "Waiting for approval. We'll unlock BabyPlus+ as soon as it comes through."
            case .cancelled:
                break
            case .failed(let message):
                Haptics.error()
                errorMessage = message
            }
        }
    }
}

// MARK: - Hero glyph

/// A small piece of theatre: three glass discs orbiting a rounded badge. It gives
/// the eye somewhere to land while the price loads.
private struct PaywallGlyph: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var spin = false

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Palette.brand.opacity(0.45), Palette.gold.opacity(0.25)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 34, height: 34)
                    .offset(y: -42)
                    .rotationEffect(.degrees(Double(index) * 120 + (spin ? 360 : 0)))
                    .blur(radius: 1)
            }

            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Palette.brand, Palette.brandDeep],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 74, height: 74)
                .overlay {
                    Text("👶")
                        .font(.system(size: 36))
                }
                .overlay(alignment: .topTrailing) {
                    Image(systemName: "sparkles")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(Palette.gold)
                        .padding(6)
                        .background(.white, in: Circle())
                        .offset(x: 6, y: -6)
                }
                .shadow(color: Palette.brand.opacity(0.4), radius: 20, y: 10)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 22).repeatForever(autoreverses: false)) { spin = true }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Feature row

private struct PaywallFeatureRow: View {
    let feature: PremiumFeature
    let isHighlighted: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: feature.systemImage)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(isHighlighted ? .white : Palette.brand)
                .frame(width: 38, height: 38)
                .background {
                    if isHighlighted {
                        Circle().fill(
                            LinearGradient(
                                colors: [Palette.brand, Palette.brandDeep],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    } else {
                        Circle().fill(Palette.brand.opacity(0.12))
                    }
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(feature.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.ink)
                Text(feature.subtitle)
                    .font(.caption)
                    .foregroundStyle(Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .liquidGlass(
            isHighlighted ? .tinted(Palette.brand) : .regular,
            in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
        )
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Plan card

private struct PlanCard: View {
    let product: Product
    let plan: SubscriptionProduct
    let isSelected: Bool
    let savingsPercent: Int?
    let introOffer: String?
    let onSelect: () -> Void

    private var planName: LocalizedStringKey {
        plan == .monthly ? "Monthly" : "Yearly"
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? Palette.brand : Palette.hairline, lineWidth: 2)
                        .frame(width: 24, height: 24)
                    if isSelected {
                        Circle()
                            .fill(Palette.brand)
                            .frame(width: 13, height: 13)
                            .transition(.scale)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(planName)
                            .font(.headline)
                            .foregroundStyle(Palette.ink)

                        if let savingsPercent {
                            PillTag(text: "Save \(savingsPercent)%", systemImage: "tag.fill", tint: Palette.gold)
                        }
                    }

                    if let introOffer {
                        Text("\(introOffer), then \(product.displayPrice)")
                            .font(.caption)
                            .foregroundStyle(Palette.inkSoft)
                    } else if plan == .yearly, let perMonth = product.monthlyEquivalentPrice {
                        Text("\(perMonth) per month, billed yearly")
                            .font(.caption)
                            .foregroundStyle(Palette.inkSoft)
                    } else {
                        Text("Billed every \(product.periodLabel)")
                            .font(.caption)
                            .foregroundStyle(Palette.inkSoft)
                    }
                }

                Spacer(minLength: 4)

                Text(product.displayPrice)
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(Palette.ink)
            }
            .padding(16)
            .liquidGlass(
                isSelected ? .interactiveTinted(Palette.brand) : .interactive,
                in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                    .strokeBorder(isSelected ? Palette.brand.opacity(0.7) : .clear, lineWidth: 1.5)
            }
        }
        .buttonStyle(.pressable)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}

// MARK: - Placeholder

private struct PlanPlaceholder: View {
    let isLoading: Bool
    let message: String?
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            if isLoading {
                ProgressView()
                Text("Fetching today's prices from the App Store…")
                    .font(.footnote)
                    .foregroundStyle(Palette.inkSoft)
            } else {
                Text(message ?? "Prices aren't available right now.")
                    .font(.footnote)
                    .foregroundStyle(Palette.inkSoft)
                    .multilineTextAlignment(.center)
                Button("Try again", action: retry)
                    .glassButtonStyle()
            }
        }
        .frame(maxWidth: .infinity)
        .glassCard(radius: Radius.medium, padding: 24)
    }
}

// MARK: - Legal

private struct LegalLinks: View {
    var body: some View {
        HStack(spacing: 16) {
            Link("Terms", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
            Text("·").foregroundStyle(Palette.inkSoft)
            Link("Privacy", destination: URL(string: "https://github.com/h-elbeheiry/babyplus/blob/main/PRIVACY.md")!)
        }
        .font(.caption)
        .tint(Palette.inkSoft)
    }
}

private extension PaywallView {
    var legal: some View {
        VStack(spacing: 8) {
            Text("Your data never leaves your iCloud account — a subscription pays for the app, not for storing your baby's life on someone else's server.")
                .font(.caption2)
                .foregroundStyle(Palette.inkSoft)
                .multilineTextAlignment(.center)
            LegalLinks()
        }
        .padding(.top, 4)
    }
}

// MARK: - Celebration

/// What someone sees the moment the purchase clears.
private struct PurchaseCelebration: View {
    let onDone: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bloom = false

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                ForEach(0..<12, id: \.self) { index in
                    Capsule()
                        .fill([Palette.brand, Palette.gold, Palette.auroraA, Palette.auroraB][index % 4])
                        .frame(width: 7, height: 18)
                        .offset(y: bloom ? -120 : -20)
                        .rotationEffect(.degrees(Double(index) / 12 * 360))
                        .opacity(bloom ? 0 : 1)
                }

                Image(systemName: "checkmark")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 96, height: 96)
                    .background(
                        LinearGradient(
                            colors: [Palette.brand, Palette.brandDeep],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: Circle()
                    )
                    .scaleEffect(bloom ? 1 : 0.5)
            }
            .frame(height: 200)

            Text("Welcome to BabyPlus+")
                .font(.title2.weight(.bold))
                .foregroundStyle(Palette.ink)

            Text("Insights, full history, exports, reminders and themes are all yours. Thank you for supporting a small app.")
                .font(.subheadline)
                .foregroundStyle(Palette.inkSoft)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                Haptics.tap()
                onDone()
            } label: {
                Text("Let's go").fontWeight(.semibold).frame(maxWidth: .infinity)
            }
            .glassButtonStyle(prominent: true)
            .controlSize(.large)
            .padding(.horizontal, 40)
            .padding(.top, 6)
        }
        .onAppear {
            Haptics.success()
            withAnimation(reduceMotion ? .easeOut(duration: 0.2) : Motion.bouncy) { bloom = true }
        }
    }
}

#if DEBUG
#Preview {
    PaywallView(highlighted: .insights)
        .environmentObject(SubscriptionService())
        .environmentObject(PaywallPresenter())
}
#endif
