import CoreData
import Foundation

/// Returns a fetch request that gathers all babies in the database, sorted by name.
public var allBabies: NSFetchRequest<Baby> {
    let request = Baby.fetchRequest() as! NSFetchRequest<Baby>
    request.sortDescriptors = [
        NSSortDescriptor(keyPath: \Baby.name, ascending: true)
    ]
    return request
}

/// Looks up one baby by its stable identifier.
///
/// Selection is remembered by `Baby.id` rather than by `NSManagedObjectID`, since
/// object IDs are local to a device and would break the moment the same account
/// opened the app on an iPad.
public func baby(withID id: UUID, in context: NSManagedObjectContext) -> Baby? {
    let request = Baby.fetchRequest() as! NSFetchRequest<Baby>
    request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
    request.fetchLimit = 1
    return try? context.fetch(request).first
}

/// How many baby profiles exist. Used to enforce the free plan's limit.
public func babyCount(in context: NSManagedObjectContext) -> Int {
    (try? context.count(for: Baby.fetchRequest())) ?? 0
}
