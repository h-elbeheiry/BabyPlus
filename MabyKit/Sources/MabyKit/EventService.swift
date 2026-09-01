import CoreData
import Logging
import Foundation

@MainActor
public final class EventService {
    let database: PersistenceController
    let logger: Logger

    init(database: PersistenceController, logger: Logger) {
        self.database = database
        self.logger = logger
    }

    private var context: NSManagedObjectContext { database.container.viewContext }

    /// Attaches the event to a baby and saves.
    ///
    /// An event with no baby is invisible everywhere in the app, so rather than
    /// writing one we refuse: a caller that can't say who the entry is for has a
    /// bug, and a rejected save is much easier to notice than a row that silently
    /// never appears.
    private func save<E: Event>(event: E, baby: Baby?) -> Result<E, AddError> {
        guard let owner = baby ?? soleBaby() else {
            context.delete(event)
            logger.error("Refused to save an event that isn't attached to a baby")
            return .failure(.noBaby)
        }

        event.baby = owner

        do {
            try context.save()
            return .success(event)
        } catch(let error) {
            logger.error("Attempted to save database with new event, but failed with reason: \(error)")
            return .failure(.databaseError)
        }
    }

    /// The only baby on file, if there is exactly one. Lets callers that predate
    /// multiple profiles — the watch app's simplest path, mainly — keep working
    /// without having to pass one explicitly.
    private func soleBaby() -> Baby? {
        let request = Baby.fetchRequest() as! NSFetchRequest<Baby>
        request.fetchLimit = 2
        let babies = (try? context.fetch(request)) ?? []
        return babies.count == 1 ? babies.first : nil
    }

    /// Removes the given events from the database.
    public func delete(events: [Event]) {
        events.forEach { context.delete($0) }

        do {
            try context.save()
        } catch(let error) {
            logger.error("Attempted to remove event, but failed with reason \(error)")
        }
    }

    /// Removes every event belonging to one baby.
    ///
    /// Deleting the baby itself cascades to its events, so this exists for the
    /// "start this log over" case rather than for deletion.
    public func deleteAll(for baby: Baby) {
        let request = NSFetchRequest<Event>(entityName: "Event")
        request.predicate = eventsBelongTo(baby)

        do {
            let events = try context.fetch(request)
            events.forEach { context.delete($0) }
            try context.save()
        } catch (let error) {
            logger.error("Attempted to remove all events for a baby, but failed with reason: \(error)")
        }
    }

    /// Adds a new feeding from a bottle.
    public func addBottle(
        for baby: Baby? = nil,
        date: Date,
        amount: Int
    ) -> Result<BottleFeedEvent, AddError> {
        let event = BottleFeedEvent(
            context: context,
            date: date,
            quantity: Int32(amount)
        )

        return save(event: event, baby: baby)
    }

    public func addBottle(for baby: Baby? = nil, amount: Int) -> Result<BottleFeedEvent, AddError> {
        addBottle(for: baby, date: Date.now, amount: amount)
    }

    /// Adds a new diaper change event to the database.
    public func addDiaperChange(
        for baby: Baby? = nil,
        date: Date,
        type: DiaperEvent.DiaperType
    ) -> Result<DiaperEvent, AddError> {
        let event = DiaperEvent(
            context: context,
            date: date,
            type: type
        )

        return save(event: event, baby: baby)
    }

    public func addDiaperChange(
        for baby: Baby? = nil,
        type: DiaperEvent.DiaperType
    ) -> Result<DiaperEvent, AddError> {
        addDiaperChange(for: baby, date: Date.now, type: type)
    }

    /// Adds a new nursing event to the database if the provided dates are valid.
    public func addNursing(
        for baby: Baby? = nil,
        start: Date,
        end: Date,
        breast: NursingEvent.Breast
    ) -> Result<NursingEvent, AddError> {
        if start > end {
            return .failure(.invalidData)
        }

        let event = NursingEvent(
            context: context,
            start: start,
            end: end,
            breast: breast
        )

        return save(event: event, baby: baby)
    }

    public func addNursing(
        for baby: Baby? = nil,
        duration: Double,
        breast: NursingEvent.Breast
    ) -> Result<NursingEvent, AddError> {
        let end = Date.now
        let start = Calendar.current.date(
            byAdding: .minute,
            value: Int(duration.rounded(.up)) * -1,
            to: end
        )!

        return addNursing(for: baby, start: start, end: end, breast: breast)
    }

    /// Adds a new sleep event to the database if the provided dates are valid.
    public func addSleep(
        for baby: Baby? = nil,
        start: Date,
        end: Date
    ) -> Result<SleepEvent, AddError> {
        if start > end {
            return .failure(.invalidData)
        }

        let event = SleepEvent(
            context: context,
            start: start,
            end: end
        )

        return save(event: event, baby: baby)
    }

    public func addSleep(for baby: Baby? = nil, duration: Double) -> Result<SleepEvent, AddError> {
        let end = Date.now
        let start = Calendar.current.date(
            byAdding: .hour,
            value: Int(duration.rounded(.up)) * -1,
            to: end
        )!

        return addSleep(for: baby, start: start, end: end)
    }

    /// Adds a new spit-up event to the database.
    public func addVomit(
        for baby: Baby? = nil,
        date: Date,
        quantity: VomitEvent.Quantity
    ) -> Result<VomitEvent, AddError> {
        let event = VomitEvent(
            context: context,
            date: date,
            quantity: quantity
        )

        return save(event: event, baby: baby)
    }

    public func addVomit(
        for baby: Baby? = nil,
        quantity: VomitEvent.Quantity
    ) -> Result<VomitEvent, AddError> {
        addVomit(for: baby, date: Date.now, quantity: quantity)
    }
}
