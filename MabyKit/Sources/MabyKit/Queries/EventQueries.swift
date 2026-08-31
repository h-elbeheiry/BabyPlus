import Factory
import CoreData
import Foundation

/// Returns a fetch request that retrieves the latest event of a given type, sorted by its start date.
public func lastEvent<E: Event>() -> NSFetchRequest<E> {
    let request = E.fetchRequest() as! NSFetchRequest<E>
    request.sortDescriptors = [
        NSSortDescriptor(keyPath: \Event.start, ascending: false)
    ]
    request.fetchLimit = 1
    return request
}

/// Every event, newest first, optionally clipped to a start date.
///
/// The `since` parameter is how the free tier's rolling history window is applied:
/// the journal asks for everything when the person is subscribed, and for the last
/// few days when they are not.
public func allEvents(since: Date? = nil) -> NSFetchRequest<Event> {
    let request = NSFetchRequest<Event>(entityName: "Event")
    request.sortDescriptors = [
        NSSortDescriptor(keyPath: \Event.start, ascending: false)
    ]
    if let since {
        request.predicate = NSPredicate(format: "start >= %@", since as NSDate)
    }
    return request
}

/// How many events exist before `date` — used to tell someone on the free plan
/// exactly how much history a subscription would bring back.
public func countEvents(before date: Date, in context: NSManagedObjectContext) -> Int {
    let request = NSFetchRequest<Event>(entityName: "Event")
    request.predicate = NSPredicate(format: "start < %@", date as NSDate)
    return (try? context.count(for: request)) ?? 0
}
