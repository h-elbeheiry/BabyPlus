import CoreData
import Foundation

/// Produces a spreadsheet of every logged event.
///
/// The columns are deliberately flat — one row per event, with a `details` column
/// that carries whatever is specific to that kind — so the file opens cleanly in
/// Numbers, Excel or Sheets without anyone having to understand our data model.
@MainActor
public final class ExportService {
    private let database: PersistenceController

    init(database: PersistenceController) {
        self.database = database
    }

    public enum ExportError: Error {
        case noData
        case writeFailed
    }

    /// Builds the CSV text for one baby's events, newest first.
    public func makeCSV(for baby: Baby) -> String {
        let request = NSFetchRequest<Event>(entityName: "Event")
        request.predicate = eventsBelongTo(baby)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Event.start, ascending: false)]
        let events = (try? database.container.viewContext.fetch(request)) ?? []
        let babyName = baby.name

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        let name = escape(babyName)
        var rows = ["baby,type,start,end,duration_minutes,amount_ml,details"]

        for event in events {
            let start = formatter.string(from: event.start)

            switch event {
            case let bottle as BottleFeedEvent:
                rows.append("\(name),Bottle,\(start),,,\(bottle.quantity),")

            case let nursing as NursingEvent:
                let minutes = Int(nursing.end.timeIntervalSince(nursing.start) / 60)
                let side: String
                switch nursing.breast {
                case .left: side = "left"
                case .right: side = "right"
                case .both: side = "both"
                }
                rows.append("\(name),Nursing,\(start),\(formatter.string(from: nursing.end)),\(minutes),,\(side)")

            case let sleep as SleepEvent:
                let minutes = Int(sleep.end.timeIntervalSince(sleep.start) / 60)
                rows.append("\(name),Sleep,\(start),\(formatter.string(from: sleep.end)),\(minutes),,")

            case let diaper as DiaperEvent:
                let kind: String
                switch diaper.type {
                case .wet: kind = "wet"
                case .dirty: kind = "dirty"
                case .mixed: kind = "mixed"
                case .clean: kind = "clean"
                }
                rows.append("\(name),Diaper,\(start),,,,\(kind)")

            case let vomit as VomitEvent:
                let size: String
                switch vomit.quantity {
                case .little: size = "little"
                case .medium: size = "medium"
                case .big: size = "big"
                }
                rows.append("\(name),Spit-up,\(start),,,,\(size)")

            default:
                rows.append("\(name),Other,\(start),,,,")
            }
        }

        return rows.joined(separator: "\n")
    }

    /// Writes the CSV to a temporary file and returns its URL, ready to hand to a
    /// share sheet.
    public func writeCSV(for baby: Baby) throws -> URL {
        let csv = makeCSV(for: baby)
        guard csv.contains("\n") else { throw ExportError.noData }

        let stamp = DateFormatter()
        stamp.dateFormat = "yyyy-MM-dd"
        let safeName = baby.name
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined(separator: "-")
        let filename = "\(safeName.isEmpty ? "BabyPlus" : safeName)-\(stamp.string(from: .now)).csv"

        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            throw ExportError.writeFailed
        }
        return url
    }

    private func escape(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") else { return value }
        return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}
