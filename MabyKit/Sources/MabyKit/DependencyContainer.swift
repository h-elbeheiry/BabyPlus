import CoreData
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
    public static let babyService = Factory { @MainActor in
        BabyService(database: database(), logger: logger())
    }

    public static let eventService = Factory { @MainActor in
        EventService(database: database(), logger: logger())
    }

    /// Aggregates the event log into the numbers the Insights screen draws.
    public static let statisticsService = Factory { @MainActor in
        StatisticsService(database: database())
    }

    /// Turns the event log into a spreadsheet.
    public static let exportService = Factory { @MainActor in
        ExportService(database: database())
    }

    /// Schedules the local notifications behind the reminders feature.
    public static let reminderService = Factory(scope: .singleton) { @MainActor in
        ReminderService()
    }

    // MARK: - Utilities
    public static let logger = Factory {
        Logger(label: "BabyPlus")
    }
}
