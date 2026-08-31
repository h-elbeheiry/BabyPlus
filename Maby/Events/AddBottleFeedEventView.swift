import Factory
import MabyKit
import SwiftUI

struct AddBottleFeedEventView: View {
    @Injected(Container.eventService) private var eventService

    /// Whose log this entry belongs to.
    let baby: Baby?

    @State private var date = Date.now
    /// The last amount used becomes the default here and for touch-and-hold logging.
    @AppStorage("babyplus.default.bottleMl") private var quantity = 120

    var body: some View {
        AddEventView(
            "Bottle feed",
            style: .bottle,
            onAdd: { eventService.addBottle(for: baby, date: date, amount: quantity) }
        ) {
            FieldCard(title: "Amount", systemImage: "drop.fill") {
                AmountField(milliliters: $quantity, presets: [60, 90, 120, 150, 180])
            }

            FieldCard(title: "When", systemImage: "clock.fill") {
                DatePicker(
                    "Time",
                    selection: $date,
                    in: Date.distantPast...Date.now
                )
                .labelsHidden()
                .datePickerStyle(.compact)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

#if DEBUG
#Preview {
    AddBottleFeedEventView(baby: nil)
}
#endif
