import CoreData

public struct PersistenceController {
    public static let shared = PersistenceController()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        guard
            let objectModelURL = Bundle.module.url(forResource: "Maby", withExtension: "momd"),
            let objectModel = NSManagedObjectModel(contentsOf: objectModelURL)
        else {
            fatalError("Failed to retrieve the object model")
        }

        container = NSPersistentCloudKitContainer(name: "Maby", managedObjectModel: objectModel)

        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }

        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })

        container.viewContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
        container.viewContext.automaticallyMergesChangesFromParent = true

        if !inMemory {
            repairRecords(in: container.viewContext)
        }
    }

    /// Brings older stores up to date with the current model.
    ///
    /// Two things can be missing from a record written before babies owned their
    /// events: the stable `Baby.id`, and the event's `baby` relationship. Both are
    /// filled in here rather than being defended against at every read site — an
    /// event with no baby would otherwise be invisible in every screen without
    /// ever being obviously broken.
    private func repairRecords(in context: NSManagedObjectContext) {
        let babyRequest = NSFetchRequest<Baby>(entityName: "Baby")
        babyRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Baby.name, ascending: true)]

        guard let babies = try? context.fetch(babyRequest), !babies.isEmpty else { return }

        var changed = false

        for baby in babies where baby.id == nil {
            baby.id = UUID()
            changed = true
        }

        // Anything logged before the relationship existed belongs to whichever
        // baby was being tracked at the time — and back then there was only one.
        let orphanRequest = NSFetchRequest<Event>(entityName: "Event")
        orphanRequest.predicate = NSPredicate(format: "baby == nil")
        if let orphans = try? context.fetch(orphanRequest), !orphans.isEmpty {
            let owner = babies[0]
            for event in orphans {
                event.baby = owner
            }
            changed = true
        }

        guard changed else { return }
        try? context.save()
    }
}

#if DEBUG
extension PersistenceController {
    /// An in-memory store with two babies and a plausible day of entries for the
    /// first of them, used by previews.
    public static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext

        let john = Baby(
            context: viewContext,
            name: "John",
            birthday: Calendar.current.date(byAdding: .month, value: -2, to: Date.now)!,
            gender: .boy
        )

        let cassandra = Baby(
            context: viewContext,
            name: "Cassandra",
            birthday: Calendar.current.date(byAdding: .day, value: -23, to: Date.now)!,
            gender: .girl
        )

        func minutesAgo(_ minutes: Int) -> Date {
            Calendar.current.date(byAdding: .minute, value: -minutes, to: Date.now)!
        }

        let nursing = NursingEvent(
            context: viewContext,
            start: minutesAgo(48),
            end: minutesAgo(24),
            breast: .left
        )
        nursing.baby = john

        let sleep = SleepEvent(context: viewContext, start: minutesAgo(180), end: minutesAgo(60))
        sleep.baby = john

        let bottle = BottleFeedEvent(context: viewContext, date: minutesAgo(320), quantity: 120)
        bottle.baby = john

        let diaper = DiaperEvent(context: viewContext, date: minutesAgo(95), type: .wet)
        diaper.baby = john

        // Cassandra gets one entry of her own so switching babies visibly changes
        // what is on screen in previews.
        let cassandraFeed = BottleFeedEvent(context: viewContext, date: minutesAgo(70), quantity: 90)
        cassandraFeed.baby = cassandra

        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()
}
#endif
