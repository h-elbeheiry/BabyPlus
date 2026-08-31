import SwiftUI
import UIKit

/// Small wrapper so call sites read as intent ("Haptics.success()") rather than as
/// UIKit plumbing, and so we can silence feedback in one place if we ever need to.
enum Haptics {
    static func tap(_ intensity: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        let generator = UIImpactFeedbackGenerator(style: intensity)
        generator.prepare()
        generator.impactOccurred()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }
}
