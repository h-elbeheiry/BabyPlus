import Factory
import MabyKit
import SwiftUI

struct AddDiaperEventView: View {
    @Injected(Container.eventService) private var eventService

    /// Whose log this entry belongs to.
    let baby: Baby?
    
    @State private var diaperType: DiaperEvent.DiaperType = .wet
    
    var body: some View {
        AddEventView(action: {
            eventService.addDiaperChange(for: baby, type: diaperType)
        }) {
            Picker("Diaper type", selection: $diaperType) {
                Text("Wet").tag(DiaperEvent.DiaperType.wet)
                Text("Dirty").tag(DiaperEvent.DiaperType.dirty)
                Text("Mixed").tag(DiaperEvent.DiaperType.mixed)
                Text("Clean").tag(DiaperEvent.DiaperType.clean)
            }
            .pickerStyle(.inline)
        }
        .navigationBarTitle("🧷 Diaper")
    }
}

struct AddDiaperEventView_Previews: PreviewProvider {
    static var previews: some View {
        AddDiaperEventView(baby: nil)
    }
}
