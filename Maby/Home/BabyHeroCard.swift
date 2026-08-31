import MabyKit
import SwiftUI

/// One summary chip on the hero card.
struct HeroChip: Identifiable, Equatable {
    let icon: String
    let text: String
    var id: String { icon + text }
}

/// Presentation-only hero card, so onboarding and previews can render the real
/// thing without a Core Data stack behind them.
struct BabyHeroCardContent: View {
    let name: String
    let age: String
    let avatar: String
    /// Short summary chips — "4 feeds", "6h sleep", and so on.
    let chips: [HeroChip]
    var accent: Color = Palette.brand
    /// Shows the chevron that hints the card can be tapped to change profile.
    var showsSwitcher = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shimmer = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                Text(avatar)
                    .font(.system(size: 40))
                    .frame(width: 62, height: 62)
                    .background {
                        Circle().fill(.white.opacity(0.22))
                    }
                    .overlay {
                        Circle().strokeBorder(.white.opacity(0.35), lineWidth: 1)
                    }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(name)
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)

                        if showsSwitcher {
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }

                    Text(age)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.82))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }

            if !chips.isEmpty {
                HStack(spacing: 8) {
                    ForEach(chips) { chip in
                        HStack(spacing: 4) {
                            Image(systemName: chip.icon)
                                .font(.caption2.weight(.bold))
                            Text(chip.text)
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.white.opacity(0.18), in: Capsule())
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [accent, accent.opacity(0.72), Palette.brandDeep],
                        startPoint: shimmer ? .topLeading : .bottomLeading,
                        endPoint: shimmer ? .bottomTrailing : .topTrailing
                    )
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
                .strokeBorder(.white.opacity(0.22), lineWidth: 1)
        }
        .shadow(color: accent.opacity(0.35), radius: 22, y: 12)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 7).repeatForever(autoreverses: true)) { shimmer = true }
        }
        .accessibilityElement(children: .combine)
    }
}

/// The live hero card at the top of the home screen, doubling as the profile
/// switcher.
///
/// The card is the one thing on screen that always says *who* you are looking at,
/// which makes it the obvious place to change that — so tapping it opens a menu of
/// profiles rather than jumping straight into an edit form.
struct BabyHeroCard: View {
    let baby: Baby?
    let stats: DailyStat?
    var accent: Color = Palette.brand
    let onEdit: () -> Void
    let onAddBaby: () -> Void

    @EnvironmentObject private var activeBaby: ActiveBaby
    @EnvironmentObject private var subscriptions: SubscriptionService

    @FetchRequest(fetchRequest: allBabies)
    private var babies: FetchedResults<Baby>

    private var canAddAnother: Bool {
        BabyLimit.canAdd(current: babies.count, isSubscribed: subscriptions.isSubscribed)
    }

    private var avatar: String {
        guard let gender = baby?.gender else { return "🍼" }
        switch gender {
        case .girl: return "👶🏻"
        case .boy: return "👶🏽"
        case .other: return "🧸"
        }
    }

    private var chips: [HeroChip] {
        guard let stats else { return [] }
        var result: [HeroChip] = [
            HeroChip(icon: "drop.fill", text: "\(stats.feeds) feed\(stats.feeds == 1 ? "" : "s")")
        ]
        if stats.sleepSeconds > 0 {
            result.append(HeroChip(icon: "moon.fill", text: TimeInterval(stats.sleepSeconds).compactDuration))
        }
        result.append(
            HeroChip(icon: "circle.grid.2x2.fill", text: "\(stats.diaperChanges) change\(stats.diaperChanges == 1 ? "" : "s")")
        )
        return result
    }

    var body: some View {
        Menu {
            if babies.count > 1 {
                Section("Switch to") {
                    ForEach(babies, id: \.objectID) { candidate in
                        Button {
                            withAnimation(Motion.arrive) { activeBaby.select(candidate) }
                            Haptics.selection()
                        } label: {
                            Label(
                                candidate.name,
                                systemImage: candidate.id == baby?.id ? "checkmark" : "person.fill"
                            )
                        }
                    }
                }
            }

            Button { onEdit() } label: {
                Label("Baby details", systemImage: "square.and.pencil")
            }

            Button { onAddBaby() } label: {
                Label(
                    canAddAnother ? "Add a baby" : "Add a baby (BabyPlus+)",
                    systemImage: canAddAnother ? "plus" : "lock.fill"
                )
            }
        } label: {
            BabyHeroCardContent(
                name: baby?.name ?? "Your baby",
                age: baby.map { "\($0.formattedAge) old" } ?? "Add a baby to get started",
                avatar: avatar,
                chips: chips,
                accent: accent,
                showsSwitcher: babies.count > 1
            )
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(baby.map { "\($0.name), \($0.formattedAge) old" } ?? "No baby yet")
        .accessibilityHint(babies.count > 1 ? "Opens the profile switcher" : "Opens baby options")
    }
}

#if DEBUG
#Preview {
    ZStack {
        AuroraBackground()
        BabyHeroCardContent(
            name: "Cassandra",
            age: "3 months, 2 weeks old",
            avatar: "👶🏻",
            chips: [
                HeroChip(icon: "drop.fill", text: "6 feeds"),
                HeroChip(icon: "moon.fill", text: "8h 20m"),
                HeroChip(icon: "circle.grid.2x2.fill", text: "5 changes")
            ]
        )
        .padding()
    }
}
#endif
