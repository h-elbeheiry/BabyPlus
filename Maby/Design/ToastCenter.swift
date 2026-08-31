import SwiftUI

/// A tiny, app-wide confirmation banner with an optional undo.
///
/// Instant logging is only safe because it is reversible: every one-touch entry
/// puts a glass pill on screen for a few seconds with an Undo that deletes the
/// row it just wrote.
@MainActor
final class ToastCenter: ObservableObject {
    struct Toast: Identifiable, Equatable {
        let id = UUID()
        let message: String
        let systemImage: String
        let tint: Color
        var undo: (() -> Void)?

        static func == (lhs: Toast, rhs: Toast) -> Bool { lhs.id == rhs.id }
    }

    @Published private(set) var current: Toast?

    private var dismissTask: Task<Void, Never>?

    func show(
        message: String,
        systemImage: String = "checkmark.circle.fill",
        tint: Color = Palette.brand,
        undo: (() -> Void)? = nil
    ) {
        dismissTask?.cancel()
        withAnimation(Motion.arrive) {
            current = Toast(message: message, systemImage: systemImage, tint: tint, undo: undo)
        }

        dismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 4_200_000_000)
            guard !Task.isCancelled else { return }
            self?.dismiss()
        }
    }

    func dismiss() {
        dismissTask?.cancel()
        withAnimation(Motion.snappy) { current = nil }
    }

    func performUndo() {
        current?.undo?()
        dismiss()
    }
}

/// The banner itself. Attached once, at the root, above everything else.
struct ToastOverlay: View {
    @EnvironmentObject private var center: ToastCenter

    var body: some View {
        VStack {
            Spacer()
            if let toast = center.current {
                HStack(spacing: 10) {
                    Image(systemName: toast.systemImage)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(toast.tint)

                    Text(toast.message)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)

                    if toast.undo != nil {
                        Divider().frame(height: 18)
                        Button("Undo") { center.performUndo() }
                            .font(.subheadline.weight(.semibold))
                            .buttonStyle(.plain)
                            .foregroundStyle(toast.tint)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .liquidGlass(.regular, in: Capsule())
                .padding(.horizontal, 24)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .onTapGesture { center.dismiss() }
                .accessibilityElement(children: .contain)
            }
        }
        .animation(Motion.arrive, value: center.current)
        .allowsHitTesting(center.current != nil)
    }
}
