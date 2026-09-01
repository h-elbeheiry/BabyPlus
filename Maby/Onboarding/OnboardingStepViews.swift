import MabyKit
import SwiftUI

// MARK: - Step 1: what the app is

/// The home screen's hero card, exactly as it will look once a baby is added.
struct WelcomeShowcase: View {
    var body: some View {
        UIShowcase(callout: "Your day, at the top of every screen", calloutIcon: "sparkles") {
            BabyHeroCardContent(
                name: "Cassandra",
                age: "3 months, 2 weeks old",
                avatar: "👶🏻",
                chips: [
                    HeroChip(icon: "drop.fill", text: "6 feeds"),
                    HeroChip(icon: "moon.fill", text: "13h 20m"),
                    HeroChip(icon: "circle.grid.2x2.fill", text: "5 changes")
                ]
            )
        }
    }
}

// MARK: - Step 2: one-touch logging

/// The real quick-log tiles, with the touch-and-hold gesture played back on a
/// loop so the shortcut is learned before it is ever needed.
struct QuickLogShowcase: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var hold: Double = 0
    @State private var showToast = false

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        UIShowcase(callout: "Touch and hold to log it instantly", accent: EventStyle.diaper.tint) {
            VStack(spacing: 10) {
                LazyVGrid(columns: columns, spacing: 10) {
                    QuickLogTileContent(
                        style: .nursing,
                        lastTime: "2 hr ago",
                        showsTimerHint: true
                    )
                    QuickLogTileContent(
                        style: .diaper,
                        lastTime: "40 min ago",
                        isHighlighted: hold >= 1,
                        holdProgress: hold
                    )
                }

                // The undo pill that follows every instant log, so nobody is
                // afraid to try the shortcut.
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(EventStyle.diaper.tint)
                    Text("Diaper change logged")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Palette.ink)
                    Divider().frame(height: 14)
                    Text("Undo")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(EventStyle.diaper.tint)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .liquidGlass(.regular, in: Capsule())
                .opacity(showToast ? 1 : 0)
                .scaleEffect(showToast ? 1 : 0.9)
                .frame(height: 34)
            }
        }
        .task { await playLoop() }
    }

    /// Runs the press → fill → confirm sequence on repeat. Reduce Motion gets the
    /// end state instead of the animation. `.task` cancels the loop when the page
    /// leaves, so we don't keep scheduling work after onboarding is gone.
    private func playLoop() async {
        guard !reduceMotion else {
            hold = 1
            showToast = true
            return
        }

        try? await Task.sleep(for: .milliseconds(500))
        while !Task.isCancelled {
            withAnimation(.linear(duration: 0.9)) { hold = 1 }
            try? await Task.sleep(for: .milliseconds(950))
            guard !Task.isCancelled else { return }
            withAnimation(Motion.bouncy) { showToast = true }
            withAnimation(.easeOut(duration: 0.3)) { hold = 0 }
            try? await Task.sleep(for: .milliseconds(1950))
            guard !Task.isCancelled else { return }
            withAnimation(Motion.snappy) { showToast = false }
            try? await Task.sleep(for: .milliseconds(700))
        }
    }
}

// MARK: - Step 3: the journal

/// Real timeline rows, with real copy, arriving one after another.
struct JournalShowcase: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visible = 0

    private struct Row {
        let style: EventStyle
        let headline: String
        let time: String
        let detail: String?
    }

    private let rows: [Row] = [
        Row(style: .nursing, headline: "Nursed on left", time: "14:05", detail: "18m"),
        Row(style: .diaper, headline: "Wet diaper", time: "13:20", detail: nil),
        Row(style: .sleep, headline: "Slept", time: "11:40", detail: "1h 25m")
    ]

    var body: some View {
        UIShowcase(callout: "Grouped by day, newest first", calloutIcon: "list.bullet", accent: EventStyle.sleep.tint) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text("Today")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Palette.ink)
                    Text("3")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Palette.inkSoft)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Palette.hairline, in: Capsule())
                    Spacer(minLength: 0)
                }

                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    TimelineRowContent(
                        style: row.style,
                        headline: row.headline,
                        time: row.time,
                        detail: row.detail,
                        isFirst: index == 0,
                        isLast: index == rows.count - 1
                    )
                    .opacity(index < visible ? 1 : 0)
                    .offset(y: index < visible ? 0 : 12)
                }
            }
        }
        .task {
            guard !reduceMotion else {
                visible = rows.count
                return
            }
            for index in 0...rows.count {
                try? await Task.sleep(for: .milliseconds(index == 0 ? 250 : 180))
                guard !Task.isCancelled else { return }
                withAnimation(Motion.arrive) { visible = index }
            }
        }
    }
}

// MARK: - Step 4: insights

/// A real Swift Charts chart, drawn from the same sample week the previews use.
struct InsightsShowcase: View {
    var body: some View {
        UIShowcase(callout: "Included with BabyPlus+", calloutIcon: "sparkles", accent: Palette.gold) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Feeding")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Palette.ink)
                        Text("Last 7 days")
                            .font(.caption2)
                            .foregroundStyle(Palette.inkSoft)
                    }
                    Spacer(minLength: 0)
                    TrendPill(change: 0.12)
                }

                FeedsChart(days: SampleStats.week(), height: 130)

                HStack(spacing: 8) {
                    StatTile(value: "7.1", caption: "feeds / day", systemImage: "drop.fill", tint: EventStyle.bottle.tint)
                    StatTile(value: "13.1h", caption: "sleep / day", systemImage: "moon.stars.fill", tint: EventStyle.sleep.tint)
                }
            }
        }
    }
}

// MARK: - Step 5: timers and reminders

/// The live session capsule and a reminder row, side by side.
struct TimersShowcase: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var elapsed: TimeInterval = 612

    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        UIShowcase(callout: "Timers survive a locked screen", calloutIcon: "timer", accent: EventStyle.nursing.tint) {
            VStack(spacing: 14) {
                LiveSessionCapsule(
                    session: .nursing(.left),
                    elapsed: elapsed,
                    onStop: {},
                    onCancel: {}
                )
                .allowsHitTesting(false)

                HStack(spacing: 12) {
                    Image(systemName: "bell.badge.fill")
                        .font(.callout)
                        .foregroundStyle(Palette.gold)
                        .frame(width: 30, height: 30)
                        .background(Palette.gold.opacity(0.14), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

                    VStack(alignment: .leading, spacing: 1) {
                        Text("Feeding reminder")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Palette.ink)
                        Text("Nudges you 3 hours after the last feed")
                            .font(.caption2)
                            .foregroundStyle(Palette.inkSoft)
                    }

                    Spacer(minLength: 0)
                    ProBadge(compact: true)
                }
                .glassCard(radius: Radius.medium, padding: 12)
            }
        }
        .onReceive(tick) { _ in
            guard !reduceMotion else { return }
            elapsed += 1
        }
    }
}
