import CoreData
import MabyKit
import SwiftUI

struct ContentView: View {
    @FetchRequest(fetchRequest: allBabies)
    private var babies: FetchedResults<Baby>

    /// Same key as iPhone. Watch has its own store, but the meaning stays identical:
    /// remember who we last logged for, never an object ID.
    @AppStorage("babyplus.activeBaby") private var activeBabyID = ""
    @StateObject private var timer = LiveSessionTimer()
    @State private var showingBabyPicker = false

    /// Honours a remembered profile when there are several; never guesses.
    private var selectedBaby: Baby? {
        if babies.isEmpty { return nil }
        if babies.count == 1 { return babies.first }
        guard let id = UUID(uuidString: activeBabyID) else { return nil }
        return babies.first(where: { $0.id == id })
    }

    var body: some View {
        NavigationStack {
            Group {
                if let baby = selectedBaby {
                    AddEventListView(baby: baby)
                        .toolbar {
                            if babies.count > 1 {
                                ToolbarItem(placement: .topBarTrailing) {
                                    Button(baby.name) { showingBabyPicker = true }
                                }
                            }
                        }
                } else if babies.isEmpty {
                    #if DEBUG
                    // Simulator CloudKit never syncs, so an empty store is normal here.
                    AddEventListView(baby: nil)
                    #else
                    noBaby
                    #endif
                } else {
                    babyPicker
                }
            }
        }
        .environmentObject(timer)
        .sheet(isPresented: $showingBabyPicker) {
            babyPicker
        }
    }

    private var noBaby: some View {
        VStack(alignment: .leading) {
            Text("No data")
                .font(.title3)

            Text("Add a baby in the iPhone app first")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    /// With more than one profile the watch has to ask, because guessing would
    /// quietly file a feed against the wrong child.
    private var babyPicker: some View {
        List(babies, id: \.objectID) { baby in
            Button {
                activeBabyID = baby.identifier.uuidString
                showingBabyPicker = false
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(baby.name)
                        .font(.headline)
                    Text("\(baby.formattedAge) old")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Who?")
    }
}

#if DEBUG
#Preview {
    ContentView()
}
#endif
