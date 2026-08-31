import CoreData
import Foundation

/// Represents a baby that was added to the app. Every event belongs to exactly one
/// of these, so a household tracking twins (or a nanny tracking someone else's
/// child) keeps two entirely separate logs.
public final class Baby: NSManagedObject, Identifiable {
    @objc public enum Gender: Int32, CaseIterable {
        case boy, girl, other
    }

    /// A stable identifier that survives iCloud sync, unlike an `NSManagedObjectID`.
    /// It is what "which baby is selected?" is remembered by.
    ///
    /// Optional in the model because CloudKit requires every attribute to be, but
    /// treated as non-optional everywhere through ``identifier``.
    @NSManaged public var id: UUID?

    @NSManaged public var name: String
    @NSManaged public var birthday: Date
    @NSManaged public var gender: Gender

    /// Everything logged for this baby. Deleting the baby cascades to all of it.
    @NSManaged public var events: NSSet?

    /// The identifier, minting one on first access if an older record predates the
    /// attribute.
    public var identifier: UUID {
        if let id { return id }
        let minted = UUID()
        id = minted
        return minted
    }

    public convenience init(
        context: NSManagedObjectContext,
        name: String,
        birthday: Date,
        gender: Gender
    ) {
        self.init(
            entity: NSEntityDescription.entity(forEntityName: "Baby", in: context)!,
            insertInto: context
        )
        self.id = UUID()
        self.name = name
        self.birthday = birthday
        self.gender = gender
    }
}

// MARK: - Generated accessors

extension Baby {
    @objc(addEventsObject:)
    @NSManaged public func addToEvents(_ value: Event)

    @objc(removeEventsObject:)
    @NSManaged public func removeFromEvents(_ value: Event)

    @objc(addEvents:)
    @NSManaged public func addToEvents(_ values: NSSet)

    @objc(removeEvents:)
    @NSManaged public func removeFromEvents(_ values: NSSet)
}
