import Factory
import MabyKit
import SwiftUI

@main
struct BabyPlusApp: App {
    @Injected(Container.container) private var persistentContainer

    /// The three objects every screen needs. They are created once, here, so a
    /// sheet can never end up talking to a different copy of the subscription
    /// state than the screen that presented it.
    @StateObject private var subscriptions = SubscriptionService()
    @StateObject private var paywall = PaywallPresenter()
    @StateObject private var preferences = AppPreferences()
    @StateObject private var toast = ToastCenter()
    @StateObject private var activeBaby = ActiveBaby()

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistentContainer.viewContext)
                .environmentObject(subscriptions)
                .environmentObject(paywall)
                .environmentObject(preferences)
                .environmentObject(toast)
                .environmentObject(activeBaby)
                .tint(preferences.effectiveAccent(isSubscribed: subscriptions.isSubscribed))
                .onAppear { preferences.registerLaunch() }
        }
        .onChange(of: scenePhase) { _, phase in
            // Coming back from the background is the cheapest reliable moment to
            // notice a subscription that lapsed, was refunded, or was bought on
            // another device.
            if phase == .active {
                Task { await subscriptions.refreshEntitlements() }
            }
        }
    }
}
