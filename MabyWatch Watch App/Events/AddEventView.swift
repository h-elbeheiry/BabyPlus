import MabyKit
import SwiftUI

private enum ButtonState: Equatable {
    case resting, loading, success
    case failed(AddError)
}

struct AddEventView<Content: View, E: Event>: View {
    @Environment(\.dismiss) private var dismiss

    let content: Content
    let onAdd: () -> Result<E, AddError>

    @State private var buttonState: ButtonState = .resting

    init(
        action: @escaping () -> Result<E, AddError>,
        @ViewBuilder _ content: () -> Content
    ) {
        self.content = content()
        self.onAdd = action
    }

    private var disableAddButton: Bool {
        buttonState != .resting
    }

    private var buttonTint: Color {
        switch buttonState {
        case .resting, .loading: return .blue
        case .success: return .green
        case .failed: return .red
        }
    }

    private func message(for error: AddError) -> String {
        switch error {
        case .invalidData: return "Check the times"
        case .noBaby: return "Pick a baby first"
        case .databaseError: return "Couldn't save"
        }
    }

    private func addAndDismiss() {
        buttonState = .loading

        switch onAdd() {
        case .success:
            buttonState = .success
            WKInterfaceDevice.current().play(.success)
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(800))
                dismiss()
            }
        case .failure(let error):
            buttonState = .failed(error)
            WKInterfaceDevice.current().play(.failure)
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(2.5))
                buttonState = .resting
            }
        }
    }

    var body: some View {
        Form {
            content

            Button(action: addAndDismiss) {
                switch buttonState {
                case .resting:
                    Text("Add")
                case .loading:
                    Text("Adding...")
                case .success:
                    Text("Added!")
                case .failed(let error):
                    Text(message(for: error))
                }
            }
            .disabled(disableAddButton)
            .buttonStyle(.borderedProminent)
            .tint(buttonTint)
            .listRowBackground(Color.clear)
        }
    }
}

#if DEBUG
#Preview {
    AddEventView(action: { .failure(.databaseError) }) {
        Text("Hello!")
    }
}
#endif
