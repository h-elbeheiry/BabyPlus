import CoreData
import Factory
import MabyKit
import SwiftUI

/// The app's shell: four tabs on a native, Liquid Glass tab bar, an ambient
/// backdrop behind everything, and the three things that can appear over the top
/// of it all (onboarding, the paywall, and the undo toast).
struct ContentView: View {
    /// Named `AppTab` rather than `Tab` so it doesn't shadow SwiftUI's own `Tab`
    /// inside this type.
    enum AppTab: Hashable {
        case today, journal, insights, settings
    }

    @EnvironmentObject private var subscriptions: SubscriptionService
    @EnvironmentObject private var paywall: PaywallPresenter
    @EnvironmentObject private var preferences: AppPreferences
    @EnvironmentObject private var toast: ToastCenter

    @StateObject private var timer = LiveSessionTimer()

    @FetchRequest(fetchRequest: allBabies)
    private var babies: FetchedResults<Baby>

    @State private var selection: AppTab = .today
    @State private var showingAddBaby = false

    private let databaseUpdates = NotificationCenter.default.publisher(
        for: .NSManagedObjectContextDidSave
    )

    private var accent: Color {
        preferences.effectiveAccent(isSubscribed: subscriptions.isSubscribed)
    }

    var body: some View {
        TabView(selection: $selection) {
            Tab("Today", systemImage: "house.fill", value: AppTab.today) {
                tabScaffold(title: "Today", seed: 0) {
                    HomeView(timer: timer)
                }
            }

            Tab("Journal", systemImage: "list.bullet.rectangle.portrait.fill", value: AppTab.journal) {
                tabScaffold(title: "Journal", seed: 1.6) {
                    JournalView()
                }
            }

            Tab("Insights", systemImage: "chart.xyaxis.line", value: AppTab.insights) {
                tabScaffold(title: "Insights", seed: 3.1) {
                    InsightsView()
                }
            }

            Tab("Settings", systemImage: "gearshape.fill", value: AppTab.settings) {
                tabScaffold(title: "Settings", seed: 4.7) {
                    SettingsView()
                }
            }
        }
        .tint(accent)
        .minimizingTabBar()
        .overlay { ToastOverlay() }
        .onChange(of: selection) { _, _ in Haptics.selection() }
        .sheet(isPresented: $paywall.isPresented) {
            PaywallView(highlighted: paywall.highlighted)
                .presentationBackground(.regularMaterial)
                .presentationCornerRadius(38)
        }
        .fullScreenCover(isPresented: needsOnboarding) {
            OnboardingFlow()
        }
        .sheet(isPresented: $showingAddBaby) {
            AddBabyView()
                .interactiveDismissDisabled(true)
                .presentationBackground(.regularMaterial)
                .presentationCornerRadius(32)
        }
        .task {
            await subscriptions.loadProducts()
            await subscriptions.refreshEntitlements()
        }
        .onAppear(perform: syncBabySheet)
        .onReceive(databaseUpdates) { _ in
            // Give any sheet that is currently dismissing a moment to finish,
            // otherwise the add-baby sheet is swallowed by the one on its way out.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: syncBabySheet)
        }
    }

    /// Onboarding runs before anything else, and takes care of adding the first
    /// baby itself.
    private var needsOnboarding: Binding<Bool> {
        Binding(
            get: { !preferences.hasCompletedOnboarding },
            set: { if !$0 { preferences.hasCompletedOnboarding = true } }
        )
    }

    private func syncBabySheet() {
        guard preferences.hasCompletedOnboarding else { return }
        showingAddBaby = babies.isEmpty
    }

    // MARK: - Tab chrome

    /// Every tab gets the same treatment: an aurora backdrop, a large title, and
    /// a Pro button for people who haven't subscribed.
    @ViewBuilder
    private func tabScaffold<Content: View>(
        title: LocalizedStringKey,
        seed: Double,
        @ViewBuilder content: () -> Content
    ) -> some View {
        NavigationStack {
            content()
                .background { AuroraBackground(seed: seed).extendedBackground() }
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    if !subscriptions.isSubscribed {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                paywall.present()
                            } label: {
                                Image(systemName: "sparkles")
                                    .foregroundStyle(Palette.gold)
                            }
                            .accessibilityLabel("Learn about BabyPlus Plus")
                        }
                    }
                }
        }
    }
}

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .mockedDependencies()
            .environmentObject(SubscriptionService())
            .environmentObject(PaywallPresenter())
            .environmentObject(AppPreferences())
            .environmentObject(ToastCenter())
            .previewDisplayName("With data")

        ContentView()
            .mockedDependencies(empty: true)
            .environmentObject(SubscriptionService())
            .environmentObject(PaywallPresenter())
            .environmentObject(AppPreferences())
            .environmentObject(ToastCenter())
            .previewDisplayName("Fresh install")
    }
}
#endif
