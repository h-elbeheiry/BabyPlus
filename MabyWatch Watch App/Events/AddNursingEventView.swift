import Factory
import MabyKit
import SwiftUI

struct AddNursingEventView: View {
    @Injected(Container.eventService) private var eventService
    @EnvironmentObject private var timer: LiveSessionTimer
    @Environment(\.dismiss) private var dismiss

    /// Whose log this entry belongs to.
    let baby: Baby?

    @State private var duration = 15.0
    @AppStorage("babyplus.default.breast") private var storedBreast = 0

    private var breast: Binding<NursingEvent.Breast> {
        Binding(
            get: { NursingEvent.Breast(rawValue: Int32(storedBreast)) ?? .left },
            set: { storedBreast = Int($0.rawValue) }
        )
    }

    private var formattedDuration: String {
        duration.formatted(.number.rounded(rule: .up))
    }

    var body: some View {
        AddEventView(action: {
            eventService.addNursing(for: baby, duration: duration, breast: breast.wrappedValue)
        }) {
            if !timer.isRunning {
                Button("Start timer") {
                    timer.start(.nursing(breast.wrappedValue))
                    WKInterfaceDevice.current().play(.start)
                    dismiss()
                }
            }

            Section("Duration") {
                VStack(alignment: .leading) {
                    Text("\(formattedDuration) minutes")

                    Slider(value: $duration, in: 2...60, step: 1) {
                        Text("Duration")
                    }
                }
                .padding(.vertical)
            }

            Picker("Breast", selection: breast) {
                Text("Left").tag(NursingEvent.Breast.left)
                Text("Right").tag(NursingEvent.Breast.right)
                Text("Both").tag(NursingEvent.Breast.both)
            }
            .pickerStyle(.inline)
        }
        .navigationTitle("🤱 Nursing")
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        AddNursingEventView(baby: nil)
            .environmentObject(LiveSessionTimer())
    }
}
#endif
