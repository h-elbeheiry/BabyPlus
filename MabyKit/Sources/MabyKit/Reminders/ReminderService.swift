import Foundation
import UserNotifications

/// Schedules the gentle nudges that BabyPlus+ subscribers can turn on.
///
/// Reminders are deliberately *interval* based rather than clock based: what a
/// parent wants to know is "it has been three hours since the last feed", not
/// "it is 3pm". Every time an event is logged the relevant reminder is pushed
/// back, so a well-tracked day is a quiet day.
public final class ReminderService {

    public enum Kind: String, CaseIterable, Identifiable, Sendable {
        case feeding
        case diaper
        case sleep

        public var id: String { rawValue }

        public var title: String {
            switch self {
            case .feeding: return "Feeding reminder"
            case .diaper: return "Diaper reminder"
            case .sleep: return "Nap reminder"
            }
        }

        public var body: String {
            switch self {
            case .feeding: return "It's been a while since the last feed. Everything alright?"
            case .diaper: return "Might be time for a fresh diaper."
            case .sleep: return "No nap logged in a while — someone may be getting sleepy."
            }
        }

        /// Sensible starting point, in hours.
        public var defaultInterval: Double {
            switch self {
            case .feeding: return 3
            case .diaper: return 3
            case .sleep: return 4
            }
        }

        var identifier: String { "babyplus.reminder.\(rawValue)" }
    }

    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    /// Asks for permission. Returns whether we ended up authorised.
    @discardableResult
    public func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    public func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    /// (Re)schedules one reminder to fire `hours` from now, replacing any pending copy.
    public func schedule(_ kind: Kind, inHours hours: Double) {
        cancel(kind)

        let content = UNMutableNotificationContent()
        content.title = kind.title
        content.body = kind.body
        content.sound = .default
        content.interruptionLevel = .passive

        let seconds = max(60, hours * 3600)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        let request = UNNotificationRequest(
            identifier: kind.identifier,
            content: content,
            trigger: trigger
        )
        center.add(request)
    }

    public func cancel(_ kind: Kind) {
        center.removePendingNotificationRequests(withIdentifiers: [kind.identifier])
    }

    public func cancelAll() {
        center.removePendingNotificationRequests(
            withIdentifiers: Kind.allCases.map(\.identifier)
        )
    }

    /// Called after an event is logged so the clock restarts rather than firing a
    /// reminder for something that just happened.
    public func bump(_ kind: Kind, inHours hours: Double, enabled: Bool) {
        guard enabled else {
            cancel(kind)
            return
        }
        schedule(kind, inHours: hours)
    }
}
