import Factory
import MabyKit
import SwiftUI

struct AddSleepEventView: View {
    @Injected(Container.eventService) private var eventService
    @EnvironmentObject private var timer: LiveSessionTimer
    @Environment(\.dismiss) private var dismiss

    /// Whose log this entry belongs to.
    let baby: Baby?

    @State private var duration = 3.0

    private var formattedDuration: String {
        duration.formatted(.number.rounded(rule: .up))
    }

    var body: some View {
        AddEventView(action: {
            eventService.addSleep(for: baby, duration: duration)
        }) {
            if !timer.isRunning {
                Button("Start timer") {
                    timer.start(.sleep)
                    WKInterfaceDevice.current().play(.start)
                    dismiss()
                }
            }

            Section("Duration") {
                VStack(alignment: .leading) {
                    Text("\(formattedDuration) hours")

                    Slider(value: $duration, in: 1...10, step: 0.5) {
                        Text("Duration")
                    }
                }
                .padding(.vertical)
            }
        }
        .navigationTitle("🌝 Sleep")
    }
}

#if DEBUG
#Preview {
    AddSleepEventView(baby: nil)
        .environmentObject(LiveSessionTimer())
}
#endif
