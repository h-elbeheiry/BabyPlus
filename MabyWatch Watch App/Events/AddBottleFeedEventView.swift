import Factory
import MabyKit
import SwiftUI

struct AddBottleFeedEventView: View {
    @Injected(Container.eventService) private var eventService

    /// Whose log this entry belongs to.
    let baby: Baby?

    /// The last amount used, same key as iPhone so a watch log feels like a hold-to-log.
    @AppStorage("babyplus.default.bottleMl") private var quantity = 120

    private var formattedAmount: String {
        let amountWithMeasurement = Measurement(
            value: Double(quantity),
            unit: UnitVolume.milliliters
        )
        return formatMl(amount: amountWithMeasurement)
    }

    var body: some View {
        AddEventView(action: {
            eventService.addBottle(for: baby, amount: quantity)
        }) {
            Section("Amount") {
                VStack(alignment: .leading) {
                    Text(formattedAmount)

                    Slider(
                        value: Binding(
                            get: { Double(quantity) },
                            set: { quantity = Int($0.rounded()) }
                        ),
                        in: 30...300,
                        step: 10
                    ) {
                        Text("Amount")
                    }
                }
                .padding(.vertical)
            }
        }
        .navigationTitle("🍼 Bottle")
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        AddBottleFeedEventView(baby: nil)
    }
}
#endif
