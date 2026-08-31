import Factory
import MabyKit
import SwiftUI

struct AddDiaperEventView: View {
    @Injected(Container.eventService) private var eventService

    /// Whose log this entry belongs to.
    let baby: Baby?

    @State private var date = Date.now
    @AppStorage("babyplus.default.diaperType") private var storedType = 0

    private var diaperType: Binding<DiaperEvent.DiaperType> {
        Binding(
            get: { DiaperEvent.DiaperType(rawValue: Int32(storedType)) ?? .wet },
            set: { storedType = Int($0.rawValue) }
        )
    }

    var body: some View {
        AddEventView(
            "Diaper change",
            style: .diaper,
            onAdd: { eventService.addDiaperChange(for: baby, date: date, type: diaperType.wrappedValue) }
        ) {
            FieldCard(title: "What did you find?", systemImage: "eye.fill") {
                ChipPicker(
                    options: [
                        .init(value: .wet, label: "Wet"),
                        .init(value: .dirty, label: "Dirty"),
                        .init(value: .mixed, label: "Mixed"),
                        .init(value: .clean, label: "Clean")
                    ],
                    selection: diaperType,
                    tint: EventStyle.diaper.tint
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
    AddDiaperEventView(baby: nil)
}
#endif
