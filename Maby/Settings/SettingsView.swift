import SwiftUI

struct SettingsView: View {
    @State private var showingEditBaby = false
    @State private var showingRemoveBaby = false
    
    private var version: String {
        let infoDictionary = Bundle.main.infoDictionary
        
        let releaseVersionNumber = infoDictionary?[
            "CFBundleShortVersionString"
        ] as? String
        
        let buildVersion = infoDictionary?[
            "CFBundleVersion"
        ] as? String
        
        if releaseVersionNumber != nil && buildVersion != nil {
            return "v\(releaseVersionNumber!) (Build \(buildVersion!))"
        } else {
            return "v1.0.0 (1)"
        }
    }
    
    var body: some View {
        List {
            Section("Baby") {
                Button(action: { showingEditBaby.toggle() }) {
                    Label("Edit baby details", systemImage: "info.square.fill")
                }
                
                Button(action: { showingRemoveBaby.toggle() }) {
                    Label("Remove baby", systemImage: "trash.square.fill")
                        .symbolRenderingMode(.multicolor)
                }
            }
            
            Section() {
                Text("Maby \(version)")
                
                Text(
                    "Made with \(Image(systemName: "heart.fill").symbolRenderingMode(.multicolor)) by Hussein using Maby"
                )
            }
            .foregroundColor(.gray)
            .listRowSeparator(.hidden)
            .frame(maxWidth: .infinity, alignment: .center)
            .clearBackground()
        }
        .sheet(isPresented: $showingEditBaby) {
            EditBabyDetailsView()
        }
        .sheet(isPresented: $showingRemoveBaby) {
            RemoveBabyView()
                .sheetSize(.medium)
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .mockedDependencies()
    }
}
