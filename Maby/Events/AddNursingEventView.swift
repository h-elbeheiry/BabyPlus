import Factory
import MabyKit
import SwiftUI

struct AddNursingEventView: View {
    @Injected(Container.eventService) private var eventService

    /// Whose log this entry belongs to.
    let baby: Baby?

    @State private var endDate = Date.now
    @State private var startDate = Date.now.addingTimeInterval(-15 * 60)
    @AppStorage("babyplus.default.breast") private var storedBreast = 0

    private var breast: Binding<NursingEvent.Breast> {
        Binding(
            get: { NursingEvent.Breast(rawValue: Int32(storedBreast)) ?? .left },
            set: { storedBreast = Int($0.rawValue) }
        )
    }

    private var duration: TimeInterval { max(0, endDate.timeIntervalSince(startDate)) }

    var body: some View {
        AddEventView(
            "Nursing",
            style: .nursing,
            onAdd: {
                eventService.addNursing(
                    for: baby,
                    start: startDate,
                    end: endDate,
                    breast: breast.wrappedValue
                )
            }
        ) {
            FieldCard(title: "Which side?", systemImage: "arrow.left.arrow.right") {
                ChipPicker(
                    options: [
                        .init(value: .left, label: "Left"),
                        .init(value: .right, label: "Right"),
                        .init(value: .both, label: "Both")
                    ],
                    selection: breast,
                    tint: EventStyle.nursing.tint
                )
            }

            FieldCard(title: "How long?", systemImage: "hourglass") {
                VStack(alignment: .leading, spacing: 12) {
                    Text(duration.compactDuration)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(Palette.ink)
                        .contentTransition(.numericText())

                    DurationShortcuts(
                        options: [5, 10, 15, 20, 30],
                        apply: { minutes in
                            withAnimation(Motion.snappy) {
                                startDate = endDate.addingTimeInterval(-Double(minutes) * 60)
                            }
                        },
                        tint: EventStyle.nursing.tint
                    )
                }
            }

            FieldCard(title: "Times", systemImage: "clock.fill") {
                VStack(spacing: 10) {
                    DatePicker("Started", selection: $startDate, in: Date.distantPast...Date.now)
                    Divider()
                    DatePicker("Finished", selection: $endDate, in: startDate...Date.distantFuture)
                }
                .font(.subheadline)
            }
        }
    }
}

#if DEBUG
#Preview {
    AddNursingEventView(baby: nil)
}
#endif
