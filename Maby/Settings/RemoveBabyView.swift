import Factory
import MabyKit
import SwiftUI

/// Deleting a baby wipes every entry with it, so the sheet asks for the name to be
/// confirmed rather than relying on a single red button.
struct RemoveBabyView: View {
    @Injected(Container.babyService) private var babyService
    @Environment(\.dismiss) private var dismiss

    @FetchRequest(fetchRequest: allBabies)
    private var babies: FetchedResults<Baby>

    @State private var confirmed = false

    private var baby: Baby? { babies.first }

    private func remove() {
        guard let baby else { return }
        babyService.remove(baby: baby)
        Haptics.warning()
        dismiss()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundStyle(.red)

                Text("Remove \(baby?.name ?? "this baby")?")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Palette.ink)
            }

            Text("This deletes every feed, nap, change and note along with the profile. It cannot be undone, and it removes them from iCloud too.")
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

#if DEBUG
#Preview {
    RemoveBabyView()
        .mockedDependencies()
}
#endif
