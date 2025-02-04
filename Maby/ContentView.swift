import CoreData
import Factory
import MabyKit
import SwiftUI
import AnimatedTabBar

struct ContentView: View {
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject private var nursingTimer = NursingTimer()
    @FetchRequest(fetchRequest: allBabies)
    private var babies: FetchedResults<Baby>
    
    @State private var showingAddBaby = false
    @State private var selectedIndex = 0
    @State private var prevSelectedIndex = 0

    private let databaseUpdates = NotificationCenter.default.publisher(
        for: .NSManagedObjectContextDidSave
    )
    
    var body: some View {
        ZStack(alignment: .bottom) {
            VStack {
                BabyCard()
                    .clearBackground()
                    .padding(.horizontal, 16)
                if nursingTimer.state != .idle {
                    TimerCapsuleView(
                        duration: nursingTimer.duration,
                        stopAction: {
                            withAnimation {
                                nursingTimer.stop()
                                nursingTimer.state = .idle
                            }
                        }
                    )
                }
                if selectedIndex == 0 {
                    AddEventListView(nursingTimer: nursingTimer)
                } else if selectedIndex == 1 {
                    JournalView()
                } else if selectedIndex == 2 {
                    SettingsView()
                }
            }
            VStack {
                AnimatedTabBar(selectedIndex: $selectedIndex, prevSelectedIndex: $prevSelectedIndex) {
                    colorButtonAt(0, type: .bell)
                    colorButtonAt(1, type: .bell)
                    colorButtonAt(2, type: .gear)
                }
                .barColor(colorScheme == .dark ? .examplePurple : .white)
                .cornerRadius(16)
                .selectedColor(.exampleGrey)
                .unselectedColor(.exampleLightGrey)
                .ballColor(.examplePurple)
                .verticalPadding(20)
                .ballTrajectory(.straight)
                .ballAnimation(.interpolatingSpring(stiffness: 130, damping: 15))
                .indentAnimation(.easeOut(duration: 0.3))
                .padding(.horizontal, 16)
                .onTapGesture {
                    let haptic = UIImpactFeedbackGenerator(style: .medium)
                    haptic.impactOccurred()
                }
            }
        }
        .sheet(isPresented: $showingAddBaby) {
            AddBabyView()
                .interactiveDismissDisabled(true)
        }
        .onAppear {
            showingAddBaby = babies.isEmpty
        }
        .onReceive(databaseUpdates) { _ in
            // Delay showing the sheet to give time for the rest of the sheets to hide.
            // Removing this results in the sheet not being shown due to the delete one being shown still.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                showingAddBaby = babies.isEmpty
            }
        }
    }

    func colorButtonAt(_ index: Int, type: ColorButton.AnimationType) -> some View {
        ColorButton(
            image: Image("colorTab\(index+1)"),
            colorImage: Image("colorTab\(index+1)Bg"),
            isSelected: selectedIndex == index,
            fromLeft: prevSelectedIndex < index,
            toLeft: selectedIndex < index,
            animationType: type)
    }

    func dropletButtonAt(_ index: Int) -> some View {
        DropletButton(imageName: "tab\(index+1)", dropletColor: .examplePurple, isSelected: selectedIndex == index)
    }

    func wiggleButtonAt(_ index: Int, name: String) -> some View {
        WiggleButton(image: Image(systemName: name), maskImage: Image(systemName: "\(name).fill"), isSelected: index == selectedIndex)
            .scaleEffect(1.2)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .mockedDependencies()
            .previewDisplayName("With data")
            .preferredColorScheme(.dark)

        ContentView()
            .mockedDependencies(empty: true)
            .previewDisplayName("Without data")
            .preferredColorScheme(.dark)
    }
}
