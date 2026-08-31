import Factory
import MabyKit
import SwiftUI

struct EditBabyDetailsView: View {
    @Injected(Container.babyService) private var babyService
    @Environment(\.dismiss) private var dismiss

    let baby: Baby

    @State private var name = ""
    @State private var gender = Baby.Gender.boy
    @State private var birthday = Date.now

    private func save() {
        switch babyService.edit(baby: baby, name: name, birthday: birthday, gender: gender) {
        case .success:
            Haptics.success()
            dismiss()
        case .failure:
            Haptics.error()
        }
    }

    var body: some View {
        BabyDetailsFormView(
            title: "Baby details",
            name: $name,
            gender: $gender,
            birthday: $birthday
        ) {
            BabyFormButton(title: "Save changes", action: save)
        }
        .onAppear {
            name = baby.name
            gender = baby.gender
            birthday = baby.birthday
        }
    }
}
