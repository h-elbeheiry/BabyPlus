import Factory
import MabyKit
import SwiftUI

struct BabyCard: View {
    @FetchRequest private var babies: FetchedResults<Baby>
    
    init() {
        self._babies = FetchRequest(fetchRequest: allBabies)
    }
    
    private var name: String {
        babies.first?.name ?? ""
    }
    
    private var age: String {
        babies.first?.formattedAge ?? ""
    }
    
    var body: some View {
        VStack {
            HStack {
                Text("👶🏻")
                    .font(.system(size: 48))
                    .padding([.trailing], 16)
                
                VStack(alignment: .leading) {
                    Text(name)
                        .font(.title)
                        .foregroundColor(.white)
                    
                    Text("\(age) old")
                        .font(.callout)
                        .foregroundColor(.gray)
                }
            }
            .padding()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient(gradient:
                                    Gradient(colors: [Color.hex("#2B27F3"), Color.hex("#872AFD")]), startPoint: .topLeading, endPoint: .bottomTrailing))
        .cornerRadius(10)
        .shadow(radius: 8)
    }
}

#if DEBUG
struct BabyCard_Previews: PreviewProvider {
    static var previews: some View {
        BabyCard()
            .mockedDependencies()
    }
}
#endif
