import Foundation

/// Everything BabyPlus+ unlocks. Keeping the list in one enum means the paywall,
/// the settings screen and every gate in the UI can never drift apart.
public enum PremiumFeature: String, CaseIterable, Identifiable, Sendable {
    case insights
    case fullHistory
    case dataExport
    case reminders
    case themes

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .insights: return "Insights & trends"
        case .fullHistory: return "Your complete history"
        case .dataExport: return "Export your data"
        case .reminders: return "Smart reminders"
        case .themes: return "Themes & accents"
        }
    }

    public var subtitle: String {
        switch self {
        case .insights:
            return "Charts for feeding, sleep and diapers, so you can spot a pattern before anyone thinks to ask about one."
        case .fullHistory:
            return "The free plan keeps the last \(FreeTier.journalHistoryDays) days. Pro keeps every entry, forever."
        case .dataExport:
            return "One tap to a spreadsheet you can hand to a doctor, a nanny or the other parent."
        case .reminders:
            return "A gentle nudge when it has been a while since the last feed, change or nap."
        case .themes:
            return "Pick the accent that suits your family and watch the glass take its colour from it."
        }
    }

    /// The one-line promise used on compact surfaces like the paywall hero.
    public var tagline: String {
        switch self {
        case .insights: return "See the patterns"
        case .fullHistory: return "Keep everything"
        case .dataExport: return "Take it with you"
        case .reminders: return "Never lose track"
        case .themes: return "Make it yours"
        }
    }

    public var systemImage: String {
        switch self {
        case .insights: return "chart.xyaxis.line"
        case .fullHistory: return "clock.arrow.circlepath"
        case .dataExport: return "square.and.arrow.up.fill"
        case .reminders: return "bell.badge.fill"
        case .themes: return "paintpalette.fill"
        }
    }
}

/// The limits that apply when someone has not subscribed. Written down explicitly
/// so the free tier is a deliberate product decision rather than an accident of
/// wherever a check happened to be added.
public enum FreeTier {
    /// How far back the journal reaches without a subscription.
    public static let journalHistoryDays = 7

    /// The oldest entry a free account can see, relative to now.
    public static var journalHorizon: Date {
        Calendar.current.date(byAdding: .day, value: -journalHistoryDays, to: .now) ?? .distantPast
    }
}
