import Factory
import MabyKit
import SwiftUI

struct AddDiaperEventView: View {
    @Injected(Container.eventService) private var eventService

    /// Whose log this entry belongs to.
    let baby: Baby?

    @AppStorage("babyplus.default.diaperType") private var storedType = 0

    private var diaperType: Binding<DiaperEvent.DiaperType> {
        Binding(
            get: { DiaperEvent.DiaperType(rawValue: Int32(storedType)) ?? .wet },
            set: { storedType = Int($0.rawValue) }
        )
    }

    var body: some View {
        AddEventView(action: {
            eventService.addDiaperChange(for: baby, type: diaperType.wrappedValue)
        }) {
            Picker("Diaper type", selection: diaperType) {
                Text("Wet").tag(DiaperEvent.DiaperType.wet)
                Text("Dirty").tag(DiaperEvent.DiaperType.dirty)
                Text("Mixed").tag(DiaperEvent.DiaperType.mixed)
                Text("Clean").tag(DiaperEvent.DiaperType.clean)
            }
            .pickerStyle(.inline)
        }
        .navigationTitle("🧷 Diaper")
    }
}

#if DEBUG
#Preview {
    AddDiaperEventView(baby: nil)
}
#endif
