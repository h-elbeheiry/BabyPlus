import CoreData
import Foundation

/// One calendar day's worth of aggregated activity.
public struct DailyStat: Identifiable, Equatable, Sendable {
    public var id: Date { day }
    /// Midnight at the start of the day these numbers cover.
    public let day: Date

    public let bottleMilliliters: Int
    public let bottleFeeds: Int
    public let nursingSessions: Int
    public let nursingSeconds: Int
    public let sleepSeconds: Int
    public let sleepSessions: Int
    public let wetDiapers: Int
    public let dirtyDiapers: Int
    public let mixedDiapers: Int
    public let cleanDiapers: Int
    public let spitUps: Int

    public var diaperChanges: Int { wetDiapers + dirtyDiapers + mixedDiapers + cleanDiapers }
    public var feeds: Int { bottleFeeds + nursingSessions }
    public var sleepHours: Double { Double(sleepSeconds) / 3600 }
    public var nursingMinutes: Double { Double(nursingSeconds) / 60 }

    public init(
        day: Date,
        bottleMilliliters: Int,
        bottleFeeds: Int,
        nursingSessions: Int,
        nursingSeconds: Int,
        sleepSeconds: Int,
        sleepSessions: Int,
        wetDiapers: Int,
        dirtyDiapers: Int,
        mixedDiapers: Int,
        cleanDiapers: Int,
        spitUps: Int
    ) {
        self.day = day
        self.bottleMilliliters = bottleMilliliters
        self.bottleFeeds = bottleFeeds
        self.nursingSessions = nursingSessions
        self.nursingSeconds = nursingSeconds
        self.sleepSeconds = sleepSeconds
        self.sleepSessions = sleepSessions
        self.wetDiapers = wetDiapers
        self.dirtyDiapers = dirtyDiapers
        self.mixedDiapers = mixedDiapers
        self.cleanDiapers = cleanDiapers
        self.spitUps = spitUps
    }

    public static func empty(day: Date) -> DailyStat {
        DailyStat(
            day: day,
            bottleMilliliters: 0, bottleFeeds: 0,
            nursingSessions: 0, nursingSeconds: 0,
            sleepSeconds: 0, sleepSessions: 0,
            wetDiapers: 0, dirtyDiapers: 0, mixedDiapers: 0, cleanDiapers: 0,
            spitUps: 0
        )
    }
}

/// A rolled-up view of a whole window, used for the "averages" row.
public struct StatsSummary: Equatable, Sendable {
    public let days: [DailyStat]

    public init(days: [DailyStat]) { self.days = days }

    public var totalFeeds: Int { days.reduce(0) { $0 + $1.feeds } }
    public var totalDiapers: Int { days.reduce(0) { $0 + $1.diaperChanges } }
    public var totalSleepSeconds: Int { days.reduce(0) { $0 + $1.sleepSeconds } }
    public var totalMilliliters: Int { days.reduce(0) { $0 + $1.bottleMilliliters } }

    /// Days that actually contain something, so a fresh install doesn't average
    /// itself down to zero.
    private var activeDays: Int {
        max(1, days.filter { $0.feeds > 0 || $0.diaperChanges > 0 || $0.sleepSeconds > 0 }.count)
    }

    public var averageFeedsPerDay: Double { Double(totalFeeds) / Double(activeDays) }
    public var averageDiapersPerDay: Double { Double(totalDiapers) / Double(activeDays) }
    public var averageSleepHours: Double { Double(totalSleepSeconds) / 3600 / Double(activeDays) }

    /// Percentage change of feeds in the most recent half of the window versus the
    /// older half. Positive means feeding has picked up.
    public var feedTrend: Double? { trend(for: { Double($0.feeds) }) }
    public var sleepTrend: Double? { trend(for: { Double($0.sleepSeconds) }) }

    private func trend(for value: (DailyStat) -> Double) -> Double? {
        guard days.count >= 4 else { return nil }
        let split = days.count / 2
        let older = days.prefix(split).map(value).reduce(0, +)
        let recent = days.suffix(days.count - split).map(value).reduce(0, +)
        guard older > 0 else { return recent > 0 ? 1 : nil }
        return (recent - older) / older
    }
}

/// Turns the raw event log into the numbers the Insights screen draws.
///
/// Everything is computed with a single fetch per window and bucketed in memory —
/// the volume of data one baby produces is tiny, and doing it this way keeps the
/// aggregation logic testable and independent of Core Data's grouping API.
@MainActor
public final class StatisticsService {
    private let database: PersistenceController
    private let calendar: Calendar

    init(database: PersistenceController, calendar: Calendar = .current) {
        self.database = database
        self.calendar = calendar
    }

    /// Aggregates one baby's last `days` calendar days, oldest first, including
    /// days with no activity so charts keep an even x-axis.
    public func dailyStats(
        for baby: Baby?,
        forLast days: Int,
        endingOn reference: Date = .now
    ) -> [DailyStat] {
        let today = calendar.startOfDay(for: reference)
        guard
            let windowStart = calendar.date(byAdding: .day, value: -(days - 1), to: today),
            let windowEnd = calendar.date(byAdding: .day, value: 1, to: today)
        else { return [] }

        let events = fetchEvents(for: baby, from: windowStart, to: windowEnd)

        var buckets: [Date: Accumulator] = [:]
        for offset in 0..<days {
            if let day = calendar.date(byAdding: .day, value: offset, to: windowStart) {
                buckets[day] = Accumulator()
            }
        }

        for event in events {
            let day = calendar.startOfDay(for: event.start)
            guard buckets[day] != nil else { continue }
            buckets[day]?.add(event)
        }

        return buckets
            .sorted { $0.key < $1.key }
            .map { $0.value.stat(for: $0.key) }
    }

    public func summary(
        for baby: Baby?,
        forLast days: Int,
        endingOn reference: Date = .now
    ) -> StatsSummary {
        StatsSummary(days: dailyStats(for: baby, forLast: days, endingOn: reference))
    }

    /// Today's numbers, for the home screen's glance row.
    public func today(for baby: Baby?, reference: Date = .now) -> DailyStat {
        dailyStats(for: baby, forLast: 1, endingOn: reference).first
            ?? .empty(day: calendar.startOfDay(for: reference))
    }

    // MARK: - Fetching

    private func fetchEvents(for baby: Baby?, from start: Date, to end: Date) -> [Event] {
        guard baby != nil else { return [] }

        let request = NSFetchRequest<Event>(entityName: "Event")
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            eventsBelongTo(baby),
            NSPredicate(
                format: "start >= %@ AND start < %@",
                start as NSDate,
                end as NSDate
            )
        ])
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Event.start, ascending: true)]

        do {
            return try database.container.viewContext.fetch(request)
        } catch {
            return []
        }
    }
}

// MARK: - Bucketing

private struct Accumulator {
    var bottleMilliliters = 0
    var bottleFeeds = 0
    var nursingSessions = 0
    var nursingSeconds = 0
    var sleepSeconds = 0
    var sleepSessions = 0
    var wet = 0, dirty = 0, mixed = 0, clean = 0
    var spitUps = 0

    mutating func add(_ event: Event) {
        switch event {
        case let bottle as BottleFeedEvent:
            bottleFeeds += 1
            bottleMilliliters += Int(bottle.quantity)

        case let nursing as NursingEvent:
            nursingSessions += 1
            nursingSeconds += max(0, Int(nursing.end.timeIntervalSince(nursing.start)))

        case let sleep as SleepEvent:
            sleepSessions += 1
            sleepSeconds += max(0, Int(sleep.end.timeIntervalSince(sleep.start)))

        case let diaper as DiaperEvent:
            switch diaper.type {
            case .wet: wet += 1
            case .dirty: dirty += 1
            case .mixed: mixed += 1
            case .clean: clean += 1
            }

        case is VomitEvent:
            spitUps += 1

        default:
            break
        }
    }

    func stat(for day: Date) -> DailyStat {
        DailyStat(
            day: day,
            bottleMilliliters: bottleMilliliters,
            bottleFeeds: bottleFeeds,
            nursingSessions: nursingSessions,
            nursingSeconds: nursingSeconds,
            sleepSeconds: sleepSeconds,
            sleepSessions: sleepSessions,
            wetDiapers: wet,
            dirtyDiapers: dirty,
            mixedDiapers: mixed,
            cleanDiapers: clean,
            spitUps: spitUps
        )
    }
}
