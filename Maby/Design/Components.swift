import SwiftUI

// MARK: - Section title

/// A heading with an optional trailing action, used above every group of content.
struct SectionTitle<Trailing: View>: View {
    let title: LocalizedStringKey
    var subtitle: LocalizedStringKey?
    @ViewBuilder var trailing: () -> Trailing

    init(
        _ title: LocalizedStringKey,
        subtitle: LocalizedStringKey? = nil,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Palette.ink)
                if let subtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(Palette.inkSoft)
                }
            }
            Spacer(minLength: 8)
            trailing()
        }
        .accessibilityElement(children: .combine)
    }
}

extension SectionTitle where Trailing == EmptyView {
    /// A heading with nothing on its trailing edge. Written as its own
    /// initialiser because Swift can't infer `Trailing` from a default argument.
    init(_ title: LocalizedStringKey, subtitle: LocalizedStringKey? = nil) {
        self.init(title, subtitle: subtitle) { EmptyView() }
    }
}

// MARK: - Event badge

/// The rounded gradient tile that identifies an event type. Sized so it works both
/// as a 44pt list icon and as a 64pt quick-action glyph.
struct EventBadge: View {
    let style: EventStyle
    var size: CGFloat = 44
    var isPulsing: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        Text(style.emoji)
            .font(.system(size: size * 0.48))
            .frame(width: size, height: size)
            .background {
                RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: style.gradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
                    .strokeBorder(.white.opacity(0.28), lineWidth: 0.8)
            }
            .shadow(color: style.tint.opacity(0.35), radius: size * 0.22, y: size * 0.1)
            .scaleEffect(pulse ? 1.06 : 1)
            .onAppear {
                guard isPulsing, !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
            .accessibilityHidden(true)
    }
}

// MARK: - Stat tile

/// A compact number + label pair used in the "today at a glance" row.
struct StatTile: View {
    let value: String
    let caption: LocalizedStringKey
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: systemImage)
                .font(.callout.weight(.semibold))
                .foregroundStyle(tint)
                .frame(height: 18)

            Text(value)
                .font(.title2.weight(.bold))
                .foregroundStyle(Palette.ink)
                .contentTransition(.numericText())
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            Text(caption)
                .font(.caption2)
                .foregroundStyle(Palette.inkSoft)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: Radius.medium, padding: 14)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Pill

struct PillTag: View {
    let text: String
    var systemImage: String?
    var tint: Color = Palette.brand

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.caption2.weight(.bold))
            }
            Text(text)
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(tint.opacity(0.14), in: Capsule())
        .overlay(Capsule().strokeBorder(tint.opacity(0.22), lineWidth: 0.6))
    }
}

/// The little gold marker that says a feature belongs to the paid tier.
struct ProBadge: View {
    var compact = false

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "sparkles")
                .font(.system(size: compact ? 9 : 11, weight: .bold))
            if !compact {
                Text("PRO")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(0.8)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, compact ? 6 : 8)
        .padding(.vertical, compact ? 4 : 4)
        .background(
            LinearGradient(
                colors: [Palette.gold, Palette.gold.opacity(0.72)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: Capsule()
        )
        .accessibilityLabel("Pro feature")
    }
}

// MARK: - Empty state

struct EmptyStateView: View {
    let emoji: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    var actionTitle: LocalizedStringKey?
    var action: (() -> Void)?

    @State private var float = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 14) {
            Text(emoji)
                .font(.system(size: 56))
                .offset(y: float ? -6 : 6)
                .animation(
                    reduceMotion ? nil : .easeInOut(duration: 2.2).repeatForever(autoreverses: true),
                    value: float
                )

            Text(title)
                .font(.headline)
                .foregroundStyle(Palette.ink)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(Palette.inkSoft)
                .multilineTextAlignment(.center)

            if let actionTitle, let action {
                Button(action: action) { Text(actionTitle).fontWeight(.semibold) }
                    .glassButtonStyle(prominent: true)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 24)
        .onAppear { float = true }
    }
}

// MARK: - Shine

/// A slow diagonal highlight that sweeps across premium surfaces, so the paywall
/// and the Pro chips read as something a little bit special.
struct ShineOverlay: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var travel: CGFloat = -1

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            LinearGradient(
                colors: [.clear, .white.opacity(0.35), .clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(width: width * 0.5)
            .rotationEffect(.degrees(18))
            .offset(x: travel * width * 1.4)
            .blendMode(.plusLighter)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 3.4).repeatForever(autoreverses: false).delay(0.6)) {
                    travel = 1.2
                }
            }
        }
        .allowsHitTesting(false)
    }
}
