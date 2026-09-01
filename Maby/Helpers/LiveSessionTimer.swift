import MabyKit

extension LiveSessionTimer.Session {
    var style: EventStyle {
        switch self {
        case .nursing: return .nursing
        case .sleep: return .sleep
        }
    }
}
