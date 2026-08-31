import CoreData
import MabyKit
import SwiftUI

/// Remembers which baby the app is currently showing.
///
/// Only the `UUID` is stored, never an `NSManagedObjectID` or an object: object
/// IDs are local to one device, so remembering one would break the moment the
/// same iCloud account opened the app on an iPad. Resolving the id against the
/// live `@FetchRequest` results also means the selection self-heals when the
/// chosen baby is deleted on another device.
@MainActor
final class ActiveBaby: ObservableObject {
    private static let key = "babyplus.activeBaby"

    @Published private(set) var id: UUID?

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.id = defaults.string(forKey: Self.key).flatMap(UUID.init(uuidString:))
    }

    func select(_ baby: Baby) {
        let identifier = baby.identifier
        guard identifier != id else { return }
        id = identifier
        defaults.set(identifier.uuidString, forKey: Self.key)
    }

    func clear() {
        id = nil
        defaults.removeObject(forKey: Self.key)
    }

    /// The selected baby, falling back to the first one on file.
    ///
    /// The fallback is what makes a fresh install, a deleted profile and a
    /// half-finished iCloud sync all behave sensibly without any special cases at
    /// the call sites.
    func resolve(in babies: FetchedResults<Baby>) -> Baby? {
        resolve(in: Array(babies))
    }

    func resolve(in babies: [Baby]) -> Baby? {
        guard !babies.isEmpty else { return nil }
        if let id, let match = babies.first(where: { $0.id == id }) { return match }
        return babies.first
    }
}

/// Whether another profile can be added on the current plan.
enum BabyLimit {
    static func canAdd(current count: Int, isSubscribed: Bool) -> Bool {
        isSubscribed || count < FreeTier.babyProfileLimit
    }
}
