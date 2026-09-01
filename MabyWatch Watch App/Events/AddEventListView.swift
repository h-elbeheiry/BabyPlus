import MabyKit
import SwiftUI

struct AddEventListView: View {
    /// Whose log the entries added here belong to.
    let baby: Baby?

    @EnvironmentObject private var timer: LiveSessionTimer
    @AppStorage("babyplus.default.breast") private var storedBreast = 0

    private var lastBreast: NursingEvent.Breast {
        NursingEvent.Breast(rawValue: Int32(storedBreast)) ?? .left
    }

    var body: some View {
        List {
            if timer.isRunning, let session = timer.session {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(session.title)
                            .font(.headline)
                        Text(timer.elapsed.clockString)
                            .font(.title2.monospacedDigit())
                        HStack {
                            Button("Cancel", role: .destructive) {
                                timer.cancel()
                                WKInterfaceDevice.current().play(.retry)
                            }
                            Button("Stop") {
                                if timer.stopAndSave(for: baby) != nil {
                                    WKInterfaceDevice.current().play(.success)
                                } else {
                                    WKInterfaceDevice.current().play(.failure)
                                }
                            }
                        }
                    }
                }
            }

            Section("Feeding") {
                if !timer.isRunning {
                    Button("Start nursing") {
                        timer.start(.nursing(lastBreast))
                        WKInterfaceDevice.current().play(.start)
                    }
                }

                NavigationLink(destination: AddNursingEventView(baby: baby)) {
                    Text("🤱 Nursing")
                }

                NavigationLink(destination: AddBottleFeedEventView(baby: baby)) {
                    Text("🍼 Bottle")
                }
            }

            Section("Hygiene") {
                NavigationLink(destination: AddDiaperEventView(baby: baby)) {
                    Text("🧷 Diaper change")
                }
            }

            Section("Health") {
                if !timer.isRunning {
                    Button("Start sleep") {
                        timer.start(.sleep)
                        WKInterfaceDevice.current().play(.start)
                    }
                }

                NavigationLink(destination: AddSleepEventView(baby: baby)) {
                    Text("🌝 Sleep")
                }

                NavigationLink(destination: AddVomitEventView(baby: baby)) {
                    Text("🤢 Vomit")
                }
            }
        }
        .navigationTitle(baby.map { $0.name } ?? "Add event")
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        AddEventListView(baby: nil)
            .environmentObject(LiveSessionTimer())
    }
}
#endif
