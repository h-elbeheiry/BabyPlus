import Factory
import MabyKit
import SwiftUI

struct AddSleepEventView: View {
    @Injected(Container.eventService) private var eventService

    /// Whose log this entry belongs to.
    let baby: Baby?

    @State private var endDate = Date.now
    @State private var startDate = Date.now.addingTimeInterval(-45 * 60)

    private var duration: TimeInterval { max(0, endDate.timeIntervalSince(startDate)) }

    var body: some View {
        AddEventView(
            "Sleep",
            style: .sleep,
            onAdd: { eventService.addSleep(for: baby, start: startDate, end: endDate) }
        ) {
            FieldCard(title: "How long?", systemImage: "hourglass") {
                VStack(alignment: .leading, spacing: 12) {
                    Text(duration.compactDuration)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(Palette.ink)
                        .contentTransition(.numericText())

                    DurationShortcuts(
                        options: [20, 45, 90, 120, 240],
                        apply: { minutes in
                            withAnimation(Motion.snappy) {
                                startDate = endDate.addingTimeInterval(-Double(minutes) * 60)
                            }
                        },
                        tint: EventStyle.sleep.tint
                    )
                }
            }

            FieldCard(title: "Times", systemImage: "clock.fill") {
                VStack(spacing: 10) {
                    DatePicker("Fell asleep", selection: $startDate, in: Date.distantPast...Date.now)
                    Divider()
                    DatePicker("Woke up", selection: $endDate, in: startDate...Date.distantFuture)
                }
                .font(.subheadline)
            }
        }
    }
}

#if DEBUG
#Preview {
    AddSleepEventView(baby: nil)
}
#endif
