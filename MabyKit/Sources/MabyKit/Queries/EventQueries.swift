import Factory
import CoreData
import Foundation

/// Returns a fetch request that retrieves the latest event of a given type for one
/// baby, sorted by its start date.
///
/// Callers that don't yet know which baby is selected can pass `nil` and set
/// `nsPredicate` later — that is how the SwiftUI `@FetchRequest` views work, since
/// their requests are built before the environment is available.
public func lastEvent<E: Event>(for baby: Baby? = nil) -> NSFetchRequest<E> {
    let request = E.fetchRequest() as! NSFetchRequest<E>
    request.sortDescriptors = [
        NSSortDescriptor(keyPath: \Event.start, ascending: false)
    ]
    request.predicate = baby.map { eventsBelongTo($0) }
    request.fetchLimit = 1
    return request
}

/// Every event for a baby, newest first, optionally clipped to a start date.
///
/// The `since` parameter is how the free tier's rolling history window is applied:
/// the journal asks for everything when the person is subscribed, and for the last
/// few days when they are not.
public func allEvents(for baby: Baby?, since: Date? = nil) -> NSFetchRequest<Event> {
    let request = NSFetchRequest<Event>(entityName: "Event")
    request.sortDescriptors = [
        NSSortDescriptor(keyPath: \Event.start, ascending: false)
    ]
    request.predicate = eventPredicate(baby: baby, since: since)
    return request
}

/// How many of a baby's events fall before `date` — used to tell someone on the
/// free plan exactly how much history a subscription would bring back.
public func countEvents(for baby: Baby?, before date: Date, in context: NSManagedObjectContext) -> Int {
    let request = NSFetchRequest<Event>(entityName: "Event")
    request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
        eventsBelongTo(baby),
        NSPredicate(format: "start < %@", date as NSDate)
    ])
    return (try? context.count(for: request)) ?? 0
}

// MARK: - Predicate helpers

/// Matches the events owned by `baby`. A nil baby matches nothing rather than
/// everything: showing one baby's entries under another's name is worse than
/// showing an empty screen.
public func eventsBelongTo(_ baby: Baby?) -> NSPredicate {
    guard let baby else { return NSPredicate(value: false) }
    return NSPredicate(format: "baby == %@", baby)
}

func eventPredicate(baby: Baby?, since: Date?) -> NSPredicate {
    var parts = [eventsBelongTo(baby)]
    if let since {
        parts.append(NSPredicate(format: "start >= %@", since as NSDate))
    }
    return NSCompoundPredicate(andPredicateWithSubpredicates: parts)
}
