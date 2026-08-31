import Factory
import MabyKit
import SwiftUI

/// The pure presentation half of a quick-log tile.
///
/// It knows nothing about Core Data, which is exactly why the onboarding can show
/// the *real* control rather than a picture of one: same view, same glass, same
/// layout, fed from a couple of strings.
struct QuickLogTileContent: View {
    /// Carries the emoji, the tint and the name, so a tile and its onboarding
    /// counterpart can never drift apart.
    let style: EventStyle
    /// "3h ago", or nil when nothing of this kind has been logged yet.
    let lastTime: String?
    var showsTimerHint = false
    var isHighlighted = false
    /// 0…1 while the user holds the tile down, drawing the ring that fills up
    /// just before an instant log fires.
    var holdProgress: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                EventBadge(style: style, size: 46, isPulsing: isHighlighted)
                Spacer(minLength: 0)
                if showsTimerHint {
                    Image(systemName: "timer")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(style.tint)
                        .padding(6)
                        .background(style.tint.opacity(0.14), in: Circle())
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(style.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)

                Text(lastTime ?? "Nothing logged yet")
                    .font(.caption2)
                    .foregroundStyle(Palette.inkSoft)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .liquidGlass(
            isHighlighted ? .interactiveTinted(style.tint) : .interactive,
            in: RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
                .trim(from: 0, to: holdProgress)
                .stroke(style.tint, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .opacity(holdProgress > 0 ? 1 : 0)
        }
        .overlay {
            RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
                .strokeBorder(isHighlighted ? style.tint.opacity(0.6) : .clear, lineWidth: 1.5)
        }
    }
}

/// A quick-log tile bound to the last event of type `E`.
///
/// Interaction is the whole point of this screen: **tap** opens the detail sheet,
/// and **touch and hold** logs the event immediately with sensible defaults. A
/// parent with one free hand at 3am should not have to fill in a form, and the
/// ring that fills under their thumb makes the shortcut discoverable the first
/// time they rest a finger on a tile.
struct QuickLogTile<E: Event>: View {
    let style: EventStyle
    /// Long-press action. Returning an event enables the undo toast; returning nil
    /// means the gesture started something else (a timer, say).
    let instantLog: () -> Event?
    let openDetails: () -> Void
    var showsTimerHint = false
    /// Copy for the confirmation toast, e.g. "Diaper change logged".
    var instantLogMessage: String?

    @FetchRequest(fetchRequest: MabyKit.lastEvent())
    private var lastEvent: FetchedResults<E>

    @EnvironmentObject private var toast: ToastCenter

    @State private var isPressing = false
    @State private var holdProgress: Double = 0
    @State private var didFire = false
    @State private var lastTimeText: String?

    private static var holdDuration: Double { 0.4 }

    /// Recomputed every half minute so "2m ago" doesn't sit there lying all day.
    private let refresh = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        QuickLogTileContent(
            style: style,
            lastTime: lastTimeText,
            showsTimerHint: showsTimerHint,
            isHighlighted: didFire,
            holdProgress: holdProgress
        )
        .scaleEffect(isPressing ? 0.96 : 1)
        .animation(Motion.snappy, value: isPressing)
        .contentShape(RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
        .onTapGesture {
            Haptics.tap()
            openDetails()
        }
        .onLongPressGesture(minimumDuration: Self.holdDuration) {
            performInstantLog()
        } onPressingChanged: { pressing in
            isPressing = pressing
            withAnimation(.linear(duration: pressing ? Self.holdDuration : 0.15)) {
                holdProgress = pressing ? 1 : 0
            }
        }
        .onAppear(perform: updateLastTime)
        .onReceive(refresh) { _ in updateLastTime() }
        .onReceive(lastEvent.publisher) { _ in updateLastTime() }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(style.title)
        .accessibilityValue(lastTimeText ?? "Nothing logged yet")
        .accessibilityHint("Double tap for details, or touch and hold to log it now")
        .accessibilityAction(named: "Log now") { performInstantLog() }
    }

    private func performInstantLog() {
        let saved = instantLog()

        withAnimation(Motion.bouncy) { didFire = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            withAnimation(Motion.snappy) { didFire = false }
        }
        updateLastTime()

        guard let saved else { return }
        Haptics.success()
        toast.show(
            message: instantLogMessage ?? "\(style.title) logged",
            systemImage: "checkmark.circle.fill",
            tint: style.tint,
            undo: { EventUndo.delete(saved) }
        )
    }

    private func updateLastTime() {
        guard let event = lastEvent.first else {
            lastTimeText = nil
            return
        }

        let reference: Date
        if let nursing = event as? NursingEvent {
            reference = nursing.end
        } else if let sleep = event as? SleepEvent {
            reference = sleep.end
        } else {
            reference = event.start
        }

        lastTimeText = reference.formatted(.relative(presentation: .numeric))
    }
}

/// Deleting a just-created event, shared by every undo affordance.
enum EventUndo {
    static func delete(_ event: Event) {
        Container.eventService().delete(events: [event])
        Haptics.tap()
    }
}

#if DEBUG
#Preview {
    ZStack {
        AuroraBackground()
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            QuickLogTileContent(style: .nursing, lastTime: "2 hr ago", showsTimerHint: true)
            QuickLogTileContent(style: .bottle, lastTime: "40 min ago")
            QuickLogTileContent(style: .diaper, lastTime: nil, holdProgress: 0.6)
            QuickLogTileContent(style: .sleep, lastTime: "1 hr ago", showsTimerHint: true)
        }
        .padding()
    }
}
#endif
