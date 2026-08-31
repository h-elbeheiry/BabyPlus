import Factory
import Foundation
import Logging

extension Container {
    // MARK: - Database & data related stuff
    public static let database = Factory(scope: .singleton) {
        PersistenceController.shared
    }
    
    public static let container = Factory(scope: .singleton) {
        database().container
    }
    
#if DEBUG
    public static let previewContainer = Factory(scope: .singleton) {
        PersistenceController.preview.container
    }
    
    public static let emptyPreviewContainer = Factory(scope: .singleton) {
        PersistenceController(inMemory: true).container
    }
#endif
    
    // MARK: - Services
    public static let babyService = Factory {
        BabyService(
            database: database(),
            eventService: eventService(),
            logger: logger()
        )
    }
    
    public static let eventService = Factory {
        EventService(database: database(), logger: logger())
    }

    /// Aggregates the event log into the numbers the Insights screen draws.
    public static let statisticsService = Factory {
        StatisticsService(database: database())
    }

    /// Turns the event log into a spreadsheet.
    public static let exportService = Factory {
        ExportService(database: database())
    }

    /// Schedules the local notifications behind the reminders feature.
    public static let reminderService = Factory(scope: .singleton) {
        ReminderService()
    }
    
    // MARK: - Utilities
    public static let logger = Factory {
        Logger(label: "BabyPlus")
    }
}
