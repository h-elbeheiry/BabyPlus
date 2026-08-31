import MabyKit
import SwiftUI

struct AddEventListView: View {
    /// Whose log the entries added here belong to.
    let baby: Baby?

    var body: some View {
        List {
            Section("Feeding") {
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
                NavigationLink(destination: AddSleepEventView(baby: baby)) {
                    Text("🌝 Sleep")
                }

                NavigationLink(destination: AddVomitEventView(baby: baby)) {
                    Text("🤢 Vomit")
                }
            }
        }
        .navigationTitle(baby.map { "Add for \($0.name)" } ?? "Add event")
    }
}

struct AddEventListView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            AddEventListView(baby: nil)
        }
    }
}
