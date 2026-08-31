import Factory
import MabyKit
import SwiftUI

struct AddBabyView: View {
    @Injected(Container.babyService) private var babyService
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var gender = Baby.Gender.boy
    @State private var birthday = Date.now

    /// Called after a successful save — onboarding uses it to advance.
    private let onSaved: (() -> Void)?
    /// Onboarding embeds this form as a page rather than presenting it, and needs
    /// to stay on screen afterwards to make its one Pro offer.
    private let dismissesOnSave: Bool

    init(dismissesOnSave: Bool = true, onSaved: (() -> Void)? = nil) {
        self.dismissesOnSave = dismissesOnSave
        self.onSaved = onSaved
    }

    private func add() {
        switch babyService.add(name: name, birthday: birthday, gender: gender) {
        case .success:
            Haptics.success()
            onSaved?()
            if dismissesOnSave { dismiss() }
        case .failure:
            Haptics.error()
        }
    }

    var body: some View {
        BabyDetailsFormView(
            title: "Who are we tracking?",
            subtitle: "Just a name and a birthday. Everything stays on your device and your private iCloud.",
            name: $name,
            gender: $gender,
            birthday: $birthday
        ) {
            BabyFormButton(title: "Start tracking", action: add)
        }
    }
}

#if DEBUG
#Preview {
    AddBabyView()
        .mockedDependencies(empty: true)
}
#endif
