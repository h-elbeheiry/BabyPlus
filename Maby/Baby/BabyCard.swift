import Factory
import MabyKit
import SwiftUI

struct BabyCard: View {
    let baby: Baby
    
    var body: some View {
        VStack {
            HStack {
                Text("👶🏻")
                    .font(.system(size: 80))
                    .padding([.trailing], 20)
                
                VStack(alignment: .leading) {
                    Text(baby.name)
                        .font(.title)
                    
                    Text(baby.age.text)
                        .font(.callout)
                        .foregroundColor(.gray)
                }
            }
            .padding()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.gray.opacity(0.2))
        .cornerRadius(10)
        .shadow(radius: 8)
        .padding()
    }
}

struct BabyCard_Previews: PreviewProvider {
    static var previews: some View {
        BabyCard(baby: Baby(
            context: Container.previewContainer().viewContext,
            name: "Test Baby",
            birthday: Date.now.addingTimeInterval(-1000000),
            gender: Baby.Gender.boy
        ))
    }
}
