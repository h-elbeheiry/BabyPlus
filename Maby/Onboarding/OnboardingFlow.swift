import Factory
import MabyKit
import SwiftUI

/// The first-run walkthrough.
///
/// Five short pages, each one pairing a sentence with a live rendering of the exact
/// control it describes, then the baby form, then a single, skippable offer of
/// BabyPlus+. The whole thing is designed to be finishable in well under a minute
/// by someone holding a baby.
struct OnboardingFlow: View {
    @EnvironmentObject private var preferences: AppPreferences
    @EnvironmentObject private var subscriptions: SubscriptionService
    @Environment(\.dismiss) private var dismiss

    @State private var page = 0
    @State private var showingPaywall = false

    private var steps: [OnboardingStep] { OnboardingStep.all }

    /// Pages: the walkthrough, then the baby form as the final page.
    private var totalPages: Int { steps.count + 1 }
    private var isFormPage: Bool { page == steps.count }

    var body: some View {
        ZStack {
            AuroraBackground(seed: Double(page) * 1.3)

            VStack(spacing: 0) {
                topBar

                TabView(selection: $page) {
                    ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                        OnboardingPage(step: step)
                            .tag(index)
                    }

                    babyForm
                        .tag(steps.count)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(Motion.arrive, value: page)

                if !isFormPage {
                    footer
                }
            }
        }
        .interactiveDismissDisabled(true)
        .sheet(isPresented: $showingPaywall, onDismiss: finish) {
            PaywallView(highlighted: .insights)
                .presentationBackground(.regularMaterial)
                .presentationCornerRadius(38)
        }
    }

    // MARK: - Chrome

    private var topBar: some View {
        HStack {
            PageDots(count: totalPages, current: page)

            Spacer(minLength: 0)

            if !isFormPage {
                Button("Skip") {
                    Haptics.tap()
                    withAnimation(Motion.arrive) { page = steps.count }
                }
                .font(.subheadline.weight(.medium))
                .buttonStyle(.plain)
                .foregroundStyle(Palette.inkSoft)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 18)
        .padding(.bottom, 6)
        .animation(Motion.snappy, value: isFormPage)
    }

    private var footer: some View {
        VStack(spacing: 12) {
            Button {
                Haptics.tap(.medium)
                withAnimation(Motion.arrive) { page += 1 }
            } label: {
                Text(page == steps.count - 1 ? "Set up your baby" : "Next")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .glassButtonStyle(prominent: true)
            .controlSize(.large)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
        .transition(.opacity)
    }

    // MARK: - Final page

    private var babyForm: some View {
        AddBabyView(dismissesOnSave: false, onSaved: offerProThenFinish)
    }

    /// Once there's a baby to track, offer the subscription exactly once. Anyone
    /// who dismisses it lands straight in the app on the free plan.
    private func offerProThenFinish() {
        guard !subscriptions.isSubscribed else {
            finish()
            return
        }
        preferences.recordProNudge()
        showingPaywall = true
    }

    private func finish() {
        preferences.hasCompletedOnboarding = true
        dismiss()
    }
}

// MARK: - Step model

/// One walkthrough page: a sentence, and the live example that goes with it.
struct OnboardingStep: Identifiable {
    let id: String
    let eyebrow: String
    let title: String
    let body: String
    let showcase: AnyView

    static let all: [OnboardingStep] = [
        OnboardingStep(
            id: "welcome",
            eyebrow: "Welcome to BabyPlus",
            title: "One place for the whole day",
            body: "Feeds, naps, changes and the odd spit-up — all in one log, so nobody has to remember whether it was five or six.",
            showcase: AnyView(WelcomeShowcase())
        ),
        OnboardingStep(
            id: "quicklog",
            eyebrow: "Logging",
            title: "One touch, one hand",
            body: "Tap a tile to fill in the details. Touch and hold it to log the whole thing straight away — with an Undo, in case a thumb slips.",
            showcase: AnyView(QuickLogShowcase())
        ),
        OnboardingStep(
            id: "journal",
            eyebrow: "Journal",
            title: "A timeline you can actually read",
            body: "Every entry in plain language, grouped by day, with the time and duration where they matter.",
            showcase: AnyView(JournalShowcase())
        ),
        OnboardingStep(
            id: "timers",
            eyebrow: "Timers",
            title: "Start it and forget it",
            body: "Nursing and naps run on a live timer that keeps going while your phone is locked, and picks up where it left off if the app closes.",
            showcase: AnyView(TimersShowcase())
        ),
        OnboardingStep(
            id: "insights",
            eyebrow: "Insights",
            title: "Turn the log into an answer",
            body: "BabyPlus+ charts feeding, sleep and diapers over time, keeps your full history, and exports the lot as a spreadsheet.",
            showcase: AnyView(InsightsShowcase())
        )
    ]
}

// MARK: - Page

private struct OnboardingPage: View {
    let step: OnboardingStep

    @State private var textAppeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                step.showcase
                    .padding(.horizontal, 24)
                    .padding(.top, 12)

                VStack(spacing: 8) {
                    Text(step.eyebrow.uppercased())
                        .font(.caption2.weight(.heavy))
                        .tracking(1.2)
                        .foregroundStyle(Palette.brand)

                    Text(step.title)
                        .font(.system(size: 27, weight: .bold, design: .rounded))
                        .foregroundStyle(Palette.ink)
                        .multilineTextAlignment(.center)

                    Text(step.body)
                        .font(.subheadline)
                        .foregroundStyle(Palette.inkSoft)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 32)
                .opacity(textAppeared ? 1 : 0)
                .offset(y: textAppeared ? 0 : 14)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 12)
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        .onAppear {
            withAnimation(reduceMotion ? .easeOut(duration: 0.2) : Motion.arrive.delay(0.18)) {
                textAppeared = true
            }
        }
    }
}

// MARK: - Dots

private struct PageDots: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index == current ? Palette.brand : Palette.hairline)
                    .frame(width: index == current ? 20 : 7, height: 7)
                    .animation(Motion.snappy, value: current)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Step \(current + 1) of \(count)")
    }
}

#if DEBUG
#Preview {
    OnboardingFlow()
        .mockedDependencies(empty: true)
        .environmentObject(AppPreferences())
        .environmentObject(SubscriptionService())
        .environmentObject(PaywallPresenter())
        .environmentObject(ToastCenter())
}
#endif
