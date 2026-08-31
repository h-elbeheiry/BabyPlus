import MabyKit
import SwiftUI

/// Presentation-only timeline entry: a rail with a node, a glass card, and a
/// sentence describing what happened. Split out from `TimelineRow` so the
/// onboarding can show a real journal row without inventing Core Data objects.
struct TimelineRowContent: View {
    let style: EventStyle
    let headline: String
    let time: String
    var detail: String?
    var isFirst = false
    var isLast = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            rail
            card
        }
        .accessibilityElement(children: .combine)
    }

    /// The vertical line that ties a day's entries together.
    private var rail: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Palette.hairline)
                .frame(width: 2)
                .frame(height: 14)
                .opacity(isFirst ? 0 : 1)

            Circle()
                .fill(style.tint)
                .frame(width: 9, height: 9)
                .overlay(Circle().strokeBorder(Palette.canvas, lineWidth: 2))

            Rectangle()
                .fill(Palette.hairline)
                .frame(width: 2)
                .frame(maxHeight: .infinity)
                .opacity(isLast ? 0 : 1)
        }
        .frame(width: 12)
        .accessibilityHidden(true)
    }

    private var card: some View {
        HStack(alignment: .center, spacing: 12) {
            EventBadge(style: style, size: 40)

            VStack(alignment: .leading, spacing: 3) {
                Text(headline)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 6) {
                    Text(time)
                    if let detail {
                        Text("·")
                        Text(detail)
                    }
                }
                .font(.caption)
                .foregroundStyle(Palette.inkSoft)
            }

            Spacer(minLength: 0)
        }
        .glassCard(radius: Radius.medium, padding: 12)
    }
}

/// One entry on the journal timeline, bound to a stored event.
struct TimelineRow: View {
    let event: Event
    var isFirst = false
    var isLast = false

    var body: some View {
        TimelineRowContent(
            style: EventStyle.forEvent(event),
            headline: EventNarrator.headline(for: event),
            time: event.start.formatted(.dateTime.hour().minute()),
            detail: EventNarrator.detail(for: event),
            isFirst: isFirst,
            isLast: isLast
        )
    }
}

// MARK: - Copy

/// Turns an event into the sentence a person would actually say.
///
/// Kept apart from the view so the same wording can be reused by the onboarding
/// preview, the watch app and any future widget without being re-derived.
enum EventNarrator {
    static func headline(for event: Event) -> String {
        switch event {
        case let bottle as BottleFeedEvent:
            return "Bottle · \(bottle.quantity) mL"

        case let nursing as NursingEvent:
            let side: String
            switch nursing.breast {
            case .left: side = "left"
            case .right: side = "right"
            case .both: side = "both sides"
            }
            return "Nursed on \(side)"

        case is SleepEvent:
            return "Slept"

        case let diaper as DiaperEvent:
            switch diaper.type {
            case .wet: return "Wet diaper"
            case .dirty: return "Dirty diaper"
            case .mixed: return "Mixed diaper"
            case .clean: return "Clean diaper"
            }

        case let vomit as VomitEvent:
            switch vomit.quantity {
            case .little: return "A little spit-up"
            case .medium: return "Spit-up"
            case .big: return "A lot of spit-up"
            }

        default:
            return "Entry"
        }
    }

    /// The secondary line — usually a duration.
    static func detail(for event: Event) -> String? {
        switch event {
        case let nursing as NursingEvent:
            return nursing.end.timeIntervalSince(nursing.start).compactDuration
        case let sleep as SleepEvent:
            return sleep.end.timeIntervalSince(sleep.start).compactDuration
        default:
            return nil
        }
    }
}

extension EventStyle {
    /// The visual identity for a concrete event instance.
    static func forEvent(_ event: Event) -> EventStyle {
        switch event {
        case is BottleFeedEvent: return .bottle
        case is NursingEvent: return .nursing
        case is SleepEvent: return .sleep
        case is DiaperEvent: return .diaper
        case is VomitEvent: return .vomit
        default: return .bottle
        }
    }
}
