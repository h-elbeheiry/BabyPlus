import Factory
import MabyKit
import SwiftUI
import Foundation
import Combine

struct AddNursingEventView: View {
    @Injected(Container.eventService) private var eventService

    @State private var startDate = Date.now
    @State private var endDate = Date.now
    @State private var breast = NursingEvent.Breast.left

    var body: some View {
        AddEventView(
            "🤱 Nursing",
            onAdd: {
                eventService.addNursing(
                    start: startDate,
                    end: endDate,
                    breast: breast
                )
            }
        ) {
            Section("Time") {
                DatePicker(
                    "Start",
                    selection: $startDate,
                    in: Date.distantPast...Date.now
                )

                DatePicker(
                    "End",
                    selection: $endDate,
                    in: startDate...Date.distantFuture
                )
            }

            Section("Breast") {
                Picker("Breast", selection: $breast) {
                    Text("Left").tag(NursingEvent.Breast.left)
                    Text("Right").tag(NursingEvent.Breast.right)
                    Text("Both").tag(NursingEvent.Breast.both)
                }
                .pickerStyle(.segmented)
            }
        }
    }
}

struct AddNursingEvent_Previews: PreviewProvider {
    static var previews: some View {
        AddNursingEventView()
    }
}

struct AddNursingTimerEventView: View {
    @Injected(Container.eventService) private var eventService
    @ObservedObject var nursingTimer: NursingTimer
    @State private var breast = NursingEvent.Breast.left
    @Binding var showingAddEvent: Bool

    private let maxDuration = 3600  // Set this to the maximum expected nursing duration in seconds. 3600 is 1 hour.

    var body: some View {
        VStack(spacing: 16) {
            if nursingTimer.state == .idle {

                Section("Choose a breast") {
                    Picker("Breast", selection: $nursingTimer.side) {
                        Text("Left").tag(NursingEvent.Breast.left as NursingEvent.Breast?)
                        Text("Right").tag(NursingEvent.Breast.right as NursingEvent.Breast?)
                        Text("Both").tag(NursingEvent.Breast.both as NursingEvent.Breast?)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }

                Section {
                    Button {
                        if let side = nursingTimer.side {
                            withAnimation {
                                nursingTimer.start(side: side)
                                showingAddEvent.toggle()
                            }
                        }
                    } label: {
                        Text("Start")
                    }
                    .tint(Color.blue)
                    .buttonStyle(.primaryAction)
                }
                .clearBackground()
                .disabled(!nursingTimer.canStart())
                .opacity(nursingTimer.canStart() ? 1 : 0.5)
            }
        }
        .padding()
    }
}

struct AddNursingTimerEventView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            AddNursingTimerEventView(
                nursingTimer: NursingTimer(),
                showingAddEvent: .constant(true)
            )
        }
    }
}
