import MabyKit
import SwiftUI

/// Shared scaffold for every "add an event" sheet.
///
/// The old version was a `Form` with a tinted button that changed its own label
/// through four states. This one keeps the good idea — visible confirmation before
/// the sheet closes — but puts it on glass, gives the primary action a fixed
/// position your thumb can find, and always opens prefilled with "now" so the
/// common case is one tap.
struct AddEventView<Content: View, E: Event>: View {
    private enum ActionState: Equatable {
        case resting, saving, saved
        case failed(AddError)
    }

    @Environment(\.dismiss) private var dismiss

    let style: EventStyle
    let title: String
    let form: Content
    let onAdd: () -> Result<E, AddError>

    @State private var state: ActionState = .resting

    init(
        _ title: String,
        style: EventStyle,
        onAdd: @escaping () -> Result<E, AddError>,
        @ViewBuilder form: () -> Content
    ) {
        self.title = title
        self.style = style
        self.onAdd = onAdd
        self.form = form()
    }

    var body: some View {
        ZStack {
            AuroraBackground(seed: 2.4)

            VStack(spacing: 0) {
                header

                ScrollView {
                    VStack(spacing: 14) {
                        form
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)

                actionButton
            }
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            EventBadge(style: style, size: 48)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Palette.ink)
                Text("Prefilled with right now — change anything you need to.")
                    .font(.caption)
                    .foregroundStyle(Palette.inkSoft)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 18)
    }

    private var actionButton: some View {
        Button(action: save) {
            HStack(spacing: 8) {
                switch state {
                case .resting:
                    Image(systemName: "plus.circle.fill")
                    Text("Log it").fontWeight(.semibold)
                case .saving:
                    ProgressView().tint(.white)
                    Text("Saving…").fontWeight(.semibold)
                case .saved:
                    Image(systemName: "checkmark.circle.fill")
                    Text("Saved").fontWeight(.semibold)
                case .failed(let error):
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(message(for: error)).fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        .glassButtonStyle(prominent: true, tint: buttonTint)
        .controlSize(.large)
        .disabled(state != .resting)
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        .animation(Motion.snappy, value: state)
    }

    private var buttonTint: Color {
        switch state {
        case .resting, .saving: return style.tint
        case .saved: return EventStyle.diaper.tint
        case .failed: return .red
        }
    }

    /// Say what actually went wrong. "Try again" on a missing baby would send
    /// someone round the same loop forever.
    private func message(for error: AddError) -> String {
        switch error {
        case .invalidData: return "Check the times and try again"
        case .noBaby: return "Pick a baby first"
        case .databaseError: return "Couldn't save — try again"
        }
    }

    private func save() {
        guard state == .resting else { return }
        state = .saving

        switch onAdd() {
        case .success:
            state = .saved
            Haptics.success()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { dismiss() }
        case .failure(let error):
            state = .failed(error)
            Haptics.error()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { state = .resting }
        }
    }
}

// MARK: - Form building blocks

/// A labelled glass card that every sheet field sits in.
struct FieldCard<Content: View>: View {
    let title: LocalizedStringKey
    var systemImage: String?
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.caption.weight(.bold))
                }
                Text(title)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(Palette.inkSoft)
            .textCase(.uppercase)

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: Radius.medium, padding: 16)
    }
}

/// A chip row — the segmented control, but on glass and big enough for a thumb.
struct ChipPicker<Value: Hashable>: View {
    struct Option: Identifiable {
        let value: Value
        let label: String
        var id: String { label }
    }

    let options: [Option]
    @Binding var selection: Value
    var tint: Color = Palette.brand

    var body: some View {
        HStack(spacing: 8) {
            ForEach(options) { option in
                let isSelected = option.value == selection
                Button {
                    withAnimation(Motion.snappy) { selection = option.value }
                    Haptics.selection()
                } label: {
                    Text(option.label)
                        .font(.subheadline.weight(isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? .white : Palette.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background {
                            if isSelected {
                                Capsule().fill(tint)
                            } else {
                                Capsule().fill(Palette.hairline.opacity(0.6))
                            }
                        }
                }
                .buttonStyle(.pressable)
                .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
            }
        }
    }
}

/// Amount entry with the values people actually use one tap away.
struct AmountField: View {
    @Binding var milliliters: Int
    let presets: [Int]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(milliliters)")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.ink)
                    .contentTransition(.numericText())
                Text("mL")
                    .font(.headline)
                    .foregroundStyle(Palette.inkSoft)

                Spacer(minLength: 0)

                Stepper("Amount", value: $milliliters.animation(Motion.snappy), in: 10...500, step: 10)
                    .labelsHidden()
            }

            HStack(spacing: 8) {
                ForEach(presets, id: \.self) { preset in
                    Button {
                        withAnimation(Motion.snappy) { milliliters = preset }
                        Haptics.selection()
                    } label: {
                        Text("\(preset)")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(milliliters == preset ? .white : Palette.ink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background {
                                Capsule().fill(
                                    milliliters == preset
                                    ? EventStyle.bottle.tint
                                    : Palette.hairline.opacity(0.6)
                                )
                            }
                    }
                    .buttonStyle(.pressable)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Amount in millilitres")
        .accessibilityValue("\(milliliters)")
    }
}

/// Duration shortcuts for the sheets that record a span rather than a moment.
struct DurationShortcuts: View {
    /// Minutes.
    let options: [Int]
    let apply: (Int) -> Void
    var tint: Color = Palette.brand

    var body: some View {
        HStack(spacing: 8) {
            ForEach(options, id: \.self) { minutes in
                Button {
                    apply(minutes)
                    Haptics.selection()
                } label: {
                    Text(minutes >= 60 ? "\(minutes / 60)h" : "\(minutes)m")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(tint)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(tint.opacity(0.14)))
                }
                .buttonStyle(.pressable)
            }
        }
    }
}
