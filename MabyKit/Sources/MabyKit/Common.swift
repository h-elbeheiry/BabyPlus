import Foundation

/// Error that can happen while attempting to add a new entity to the database.
public enum AddError: Error, Equatable {
    case invalidData, databaseError
    /// The entry had no baby to belong to — either none has been added yet, or
    /// several exist and the caller didn't say which.
    case noBaby
}
