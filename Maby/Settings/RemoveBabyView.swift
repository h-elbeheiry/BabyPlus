import Factory
import MabyKit
import SwiftUI

/// Deleting a baby wipes every entry with it, so the sheet makes the consequence
/// explicit and requires an acknowledgement rather than relying on a red button.
struct RemoveBabyView: View {
    @Injected(Container.babyService) private var babyService
    @Environment(\.dismiss) private var dismiss

    let baby: Baby
    /// Called after the delete goes through, so the caller can move the selection
    /// on to whoever is left.
    var onRemoved: (() -> Void)?

    @State private var confirmed = false

    private var entryCount: Int { baby.events?.count ?? 0 }

    private func remove() {
        babyService.remove(baby: baby)
        Haptics.warning()
        onRemoved?()
        dismiss()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundStyle(.red)

                Text("Remove \(baby.name)?")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Palette.ink)
            }

            Text("This deletes \(baby.name)'s \(entryCount) \(entryCount == 1 ? "entry" : "entries") along with the profile. It cannot be undone, and it removes them from iCloud too. Any other babies you track are unaffected.")
                .font(.subheadline)
                .foregroundStyle(Palette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)

            Toggle(isOn: $confirmed.animation(Motion.snappy)) {
                Text("I understand this can't be undone")
                    .font(.footnote)
                    .foregroundStyle(Palette.ink)
            }
            .tint(.red)

            VStack(spacing: 10) {
                Button(role: .destructive, action: remove) {
                    Text("Delete everything")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .glassButtonStyle(prominent: true, tint: .red)
                .controlSize(.large)
                .disabled(!confirmed)
                .opacity(confirmed ? 1 : 0.5)

                Button("Keep everything") { dismiss() }
                    .glassButtonStyle()
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
            }
            .padding(.top, 2)
        }
        .padding(22)
        .frame(maxHeight: .infinity, alignment: .top)
    }
}
