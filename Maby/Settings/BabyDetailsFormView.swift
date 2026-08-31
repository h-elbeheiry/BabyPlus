import MabyKit
import SwiftUI

/// The name / gender / birthday form, shared by "add a baby", "edit baby" and the
/// last step of onboarding.
struct BabyDetailsFormView<Confirm: View>: View {
    let title: String
    let subtitle: String
    let confirmButton: Confirm

    @Binding private var name: String
    @Binding private var gender: Baby.Gender
    @Binding private var birthday: Date

    @FocusState private var nameFocused: Bool

    init(
        title: String,
        subtitle: String = "You can change any of this later.",
        name: Binding<String>,
        gender: Binding<Baby.Gender>,
        birthday: Binding<Date>,
        @ViewBuilder _ button: () -> Confirm
    ) {
        self.title = title
        self.subtitle = subtitle
        self._name = name
        self._gender = gender
        self._birthday = birthday
        self.confirmButton = button()
    }

    private var isValid: Bool { isValidBaby(name: name, birthday: birthday) }

    private var avatar: String {
        switch gender {
        case .girl: return "👶🏻"
        case .boy: return "👶🏽"
        case .other: return "🧸"
        }
    }

    var body: some View {
        ZStack {
            AuroraBackground(seed: 0.7)

            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 18) {
                        header

                        FieldCard(title: "Name", systemImage: "textformat") {
                            TextField("What should we call them?", text: $name)
                                .font(.body)
                                .textInputAutocapitalization(.words)
                                .autocorrectionDisabled()
                                .focused($nameFocused)
                                .submitLabel(.done)
                        }

                        FieldCard(title: "Gender", systemImage: "person.fill") {
                            ChipPicker(
                                options: [
                                    .init(value: Baby.Gender.boy, label: "Boy"),
                                    .init(value: Baby.Gender.girl, label: "Girl"),
                                    .init(value: Baby.Gender.other, label: "Other")
                                ],
                                selection: $gender
                            )
                        }

                        FieldCard(title: "Birthday", systemImage: "birthday.cake.fill") {
                            DatePicker(
                                "Birthday",
                                selection: $birthday,
                                in: Date.distantPast...Date.now,
                                displayedComponents: [.date]
                            )
                            .labelsHidden()
                            .datePickerStyle(.compact)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)

                confirmButton
                    .disabled(!isValid)
                    .opacity(isValid ? 1 : 0.55)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                    .animation(Motion.snappy, value: isValid)
            }
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            Text(avatar)
                .font(.system(size: 68))
                .contentTransition(.opacity)
                .animation(Motion.bouncy, value: gender)

            Text(title)
                .font(.title.weight(.bold))
                .foregroundStyle(Palette.ink)

            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(Palette.inkSoft)
                .multilineTextAlignment(.center)
        }
    }
}

/// The standard confirm button for the form above, so its three call sites look
/// and behave the same.
struct BabyFormButton: View {
    let title: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap(.medium)
            action()
        } label: {
            Text(title)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .glassButtonStyle(prominent: true)
        .controlSize(.large)
    }
}

#if DEBUG
#Preview {
    BabyDetailsFormView(
        title: "Add your baby",
        name: .constant("Cassandra"),
        gender: .constant(.girl),
        birthday: .constant(.now)
    ) {
        BabyFormButton(title: "Add baby") { }
    }
}
#endif
