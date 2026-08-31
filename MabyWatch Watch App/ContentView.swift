import CoreData
import MabyKit
import SwiftUI

struct ContentView: View {
    @FetchRequest(fetchRequest: allBabies)
    private var babies: FetchedResults<Baby>

    var body: some View {
        NavigationStack {
            // In the simulator, Core Data will NEVER sync with CloudKit and
            // therefore we'd never have any data to show even if there is indeed a
            // baby already added in the main app. So only run the check in
            // production builds. Yeah, I know, I know...
            #if DEBUG
            AddEventListView(baby: babies.first)
            #else
            if babies.isEmpty {
                noBaby
            } else if babies.count == 1 {
                AddEventListView(baby: babies.first)
            } else {
                babyPicker
            }
            #endif
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
            NavigationLink {
                AddEventListView(baby: baby)
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

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
