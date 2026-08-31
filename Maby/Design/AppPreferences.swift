import Combine
import MabyKit
import SwiftUI

/// The accents a subscriber can choose between. The whole app tints from here, so
/// picking one re-colours the glass, the buttons and the charts in one go.
enum AccentTheme: String, CaseIterable, Identifiable {
    case violet, blush, ocean, meadow, dusk

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .violet: return "Violet"
        case .blush: return "Blush"
        case .ocean: return "Ocean"
        case .meadow: return "Meadow"
        case .dusk: return "Dusk"
        }
    }

    var color: Color {
        switch self {
        case .violet: return Palette.brand
        case .blush: return Color.adaptive(light: 0xE0568C, dark: 0xFF8FB8)
        case .ocean: return Color.adaptive(light: 0x1274C4, dark: 0x62B6F7)
        case .meadow: return Color.adaptive(light: 0x1E9E6A, dark: 0x5FD9A2)
        case .dusk: return Color.adaptive(light: 0xC2571F, dark: 0xFF9A5C)
        }
    }

    /// Free accounts get the house colour; the rest come with a subscription.
    var isPremium: Bool { self != .violet }
}

/// Lightweight, UserDefaults-backed app preferences.
///
/// This is deliberately not in `MabyKit`: none of it is data worth syncing, and
/// keeping it here means the watch app doesn't inherit iOS-only concepts.
@MainActor
final class AppPreferences: ObservableObject {
    private enum Key {
        static let onboardingVersion = "babyplus.onboarding.completedVersion"
        static let accent = "babyplus.theme.accent"
        static let reminderEnabled = "babyplus.reminders.enabled."
        static let reminderInterval = "babyplus.reminders.interval."
        static let launchCount = "babyplus.launchCount"
        static let paywallLastShown = "babyplus.paywall.lastShown"
    }

    /// Bump this when the onboarding gains a step worth re-showing to everyone.
    static let currentOnboardingVersion = 1

    private let defaults: UserDefaults

    @Published var hasCompletedOnboarding: Bool {
        didSet {
            defaults.set(
                hasCompletedOnboarding ? Self.currentOnboardingVersion : 0,
                forKey: Key.onboardingVersion
            )
        }
    }

    @Published var accent: AccentTheme {
        didSet { defaults.set(accent.rawValue, forKey: Key.accent) }
    }

    @Published private(set) var launchCount: Int

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.hasCompletedOnboarding =
            defaults.integer(forKey: Key.onboardingVersion) >= Self.currentOnboardingVersion
        self.accent = AccentTheme(rawValue: defaults.string(forKey: Key.accent) ?? "") ?? .violet
        self.launchCount = defaults.integer(forKey: Key.launchCount)
    }

    func registerLaunch() {
        launchCount += 1
        defaults.set(launchCount, forKey: Key.launchCount)
    }

    /// The effective accent — a lapsed subscriber quietly falls back to the free
    /// colour rather than keeping a paid one.
    func effectiveAccent(isSubscribed: Bool) -> Color {
        (accent.isPremium && !isSubscribed) ? AccentTheme.violet.color : accent.color
    }

    // MARK: - Reminders

    func isReminderEnabled(_ kind: ReminderService.Kind) -> Bool {
        defaults.bool(forKey: Key.reminderEnabled + kind.rawValue)
    }

    func setReminder(_ kind: ReminderService.Kind, enabled: Bool) {
        defaults.set(enabled, forKey: Key.reminderEnabled + kind.rawValue)
        objectWillChange.send()
    }

    func reminderInterval(_ kind: ReminderService.Kind) -> Double {
        let stored = defaults.double(forKey: Key.reminderInterval + kind.rawValue)
        return stored > 0 ? stored : kind.defaultInterval
    }

    func setReminderInterval(_ kind: ReminderService.Kind, hours: Double) {
        defaults.set(hours, forKey: Key.reminderInterval + kind.rawValue)
        objectWillChange.send()
    }

    // MARK: - Paywall pacing

    /// We only ever nudge someone about Pro once a week, unprompted.
    var shouldOfferProNudge: Bool {
        let last = defaults.double(forKey: Key.paywallLastShown)
        guard last > 0 else { return true }
        return Date.now.timeIntervalSince1970 - last > 60 * 60 * 24 * 7
    }

    func recordProNudge() {
        defaults.set(Date.now.timeIntervalSince1970, forKey: Key.paywallLastShown)
    }
}
