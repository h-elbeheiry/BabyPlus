import Factory
import MabyKit
import SwiftUI

struct AddVomitEventView: View {
    @Injected(Container.eventService) private var eventService

    /// Whose log this entry belongs to.
    let baby: Baby?

    @State private var date = Date.now
    @State private var quantity = VomitEvent.Quantity.medium

    var body: some View {
        AddEventView(
            "Spit-up",
            style: .vomit,
            onAdd: { eventService.addVomit(for: baby, date: date, quantity: quantity) }
        ) {
            FieldCard(title: "How much?", systemImage: "chart.bar.fill") {
                ChipPicker(
                    options: [
                        .init(value: .little, label: "A little"),
                        .init(value: .medium, label: "Some"),
                        .init(value: .big, label: "A lot")
                    ],
                    selection: $quantity,
                    tint: EventStyle.vomit.tint
                )
            }

            FieldCard(title: "When", systemImage: "clock.fill") {
                DatePicker("Time", selection: $date, in: Date.distantPast...Date.now)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

#if DEBUG
#Preview {
    AddVomitEventView(baby: nil)
}
#endif
