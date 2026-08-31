import Combine
import Factory
import MabyKit
import SwiftUI

/// A single running stopwatch for the two things that have a duration: nursing and
/// sleep.
///
/// The old implementation only knew about nursing and leaked its Combine timer on
/// every start. This one keeps one subscription, derives the elapsed time from the
/// start date rather than counting ticks (so it stays correct if the app is
/// backgrounded or the device sleeps), and can be persisted across launches.
@MainActor
final class LiveSessionTimer: ObservableObject {

    enum Session: Equatable {
        case nursing(NursingEvent.Breast)
        case sleep

        var style: EventStyle {
            switch self {
            case .nursing: return .nursing
            case .sleep: return .sleep
            }
        }

        var title: String {
            switch self {
            case .nursing(.left): return "Nursing · left"
            case .nursing(.right): return "Nursing · right"
            case .nursing(.both): return "Nursing · both"
            case .sleep: return "Sleeping"
            }
        }
    }

    @Injected(Container.eventService) private var eventService

    @Published private(set) var session: Session?
    @Published private(set) var startedAt: Date?
    /// Seconds elapsed, republished once a second while a session runs.
    @Published private(set) var elapsed: TimeInterval = 0

    private var ticker: AnyCancellable?

    private enum Key {
        static let session = "babyplus.liveSession.kind"
        static let breast = "babyplus.liveSession.breast"
        static let start = "babyplus.liveSession.start"
    }

    var isRunning: Bool { session != nil }

    init() {
        restore()
    }

    // MARK: - Control

    func start(_ session: Session) {
        guard self.session == nil else { return }
        let now = Date.now
        self.session = session
        self.startedAt = now
        self.elapsed = 0
        persist(session: session, start: now)
        startTicking()
        Haptics.tap(.medium)
    }

    /// Stops the stopwatch and writes the event against `baby`. Returns the saved
    /// event so the caller can offer an undo.
    @discardableResult
    func stopAndSave(for baby: Baby?) -> Event? {
        guard let session, let startedAt else { return nil }
        stopTicking()

        let end = Date.now
        let saved: Event?

        switch session {
        case .nursing(let breast):
            saved = try? eventService
                .addNursing(for: baby, start: startedAt, end: end, breast: breast)
                .get()
        case .sleep:
            saved = try? eventService
                .addSleep(for: baby, start: startedAt, end: end)
                .get()
        }

        clear()
        if saved != nil { Haptics.success() } else { Haptics.error() }
        return saved
    }

    /// Abandons the running session without recording anything.
    func cancel() {
        stopTicking()
        clear()
        Haptics.warning()
    }

    // MARK: - Ticking

    private func startTicking() {
        ticker = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self, let start = self.startedAt else { return }
                self.elapsed = Date.now.timeIntervalSince(start)
            }
    }

    private func stopTicking() {
        ticker?.cancel()
        ticker = nil
    }

    private func clear() {
        session = nil
        startedAt = nil
        elapsed = 0
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: Key.session)
        defaults.removeObject(forKey: Key.breast)
        defaults.removeObject(forKey: Key.start)
    }

    // MARK: - Persistence

    /// A nursing session can easily outlive a trip to the app switcher, so the
    /// running stopwatch survives a relaunch.
    private func persist(session: Session, start: Date) {
        let defaults = UserDefaults.standard
        defaults.set(start, forKey: Key.start)
        switch session {
        case .nursing(let breast):
            defaults.set("nursing", forKey: Key.session)
            defaults.set(Int(breast.rawValue), forKey: Key.breast)
        case .sleep:
            defaults.set("sleep", forKey: Key.session)
        }
    }

    private func restore() {
        let defaults = UserDefaults.standard
        guard
            let kind = defaults.string(forKey: Key.session),
            let start = defaults.object(forKey: Key.start) as? Date
        else { return }

        switch kind {
        case "nursing":
            let raw = Int32(defaults.integer(forKey: Key.breast))
            session = .nursing(NursingEvent.Breast(rawValue: raw) ?? .left)
        case "sleep":
            session = .sleep
        default:
            return
        }

        startedAt = start
        elapsed = Date.now.timeIntervalSince(start)
        startTicking()
    }
}

// MARK: - Formatting

extension TimeInterval {
    /// "01:23:45" for the running capsule.
    var clockString: String {
        let total = Int(max(0, self))
        return String(format: "%02d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
    }

    /// "1h 23m" for summaries.
    var compactDuration: String {
        let total = Int(max(0, self))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 { return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h" }
        if minutes > 0 { return "\(minutes)m" }
        return "\(total)s"
    }
}
