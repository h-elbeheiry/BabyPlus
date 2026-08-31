import Logging
import Foundation

/// Returns whether the given parameters constitue a valid baby entry or not.
public func isValidBaby(name: String, birthday: Date) -> Bool {
    !name.isEmpty && birthday < Date.now
}

public class BabyService {
    let database: PersistenceController
    let logger: Logger

    init(database: PersistenceController, logger: Logger) {
        self.database = database
        self.logger = logger
    }
    
    /// Adds a new baby to the database, checking that the parameters are correct.
    public func add(
        name: String,
        birthday: Date,
        gender: Baby.Gender
    ) -> Result<Baby, AddError> {
        if !isValidBaby(name: name, birthday: birthday) {
            return .failure(.invalidData)
        }
        
        let baby = Baby(
            context: database.container.viewContext,
            name: name,
            birthday: birthday,
            gender: gender
        )
        
        do {
            try database.container.viewContext.save()
            return .success(baby)
        } catch(let error) {
            logger.error("Attempted to save database with new baby, but failed with reason: \(error)")
            return .failure(.databaseError)
        }
    }
    
    /// Edits the given baby with the provided details.
    public func edit(
        baby: Baby,
        name: String,
        birthday: Date,
        gender: Baby.Gender
    ) -> Result<Baby, AddError> {
        if !isValidBaby(name: name, birthday: birthday) {
            return .failure(.invalidData)
        }
        
        baby.name = name
        baby.gender = gender
        baby.birthday = birthday
        
        do {
            try database.container.viewContext.save()
            return .success(baby)
        } catch (let error) {
            logger.error("Attempted to save database after editing baby, but failed with reason: \(error)")
            return .failure(.databaseError)
        }
    }
    
    /// Removes the given baby, and with it everything ever logged for them.
    ///
    /// The events go via the model's cascade rule rather than a blanket delete —
    /// the old implementation wiped *every* event in the store, which quietly took
    /// a sibling's whole history with it.
    public func remove(baby: Baby) {
        database.container.viewContext.delete(baby)

        do {
            try database.container.viewContext.save()
        } catch (let error) {
            logger.error("Attempted to save database after removing baby, but failed with reason: \(error)")
        }
    }
}
