import CoreData
import Factory
import MabyKit
import SwiftUI

/// Everything that has happened, newest first, as a timeline rather than a table.
///
/// The free plan sees a rolling window; the banner at the bottom says exactly how
/// many older entries are waiting rather than pretending they don't exist.
struct JournalView: View {
    @Injected(Container.eventService) private var eventService

    /// Whose log is on screen.
    let baby: Baby?

    @EnvironmentObject private var subscriptions: SubscriptionService
    @EnvironmentObject private var paywall: PaywallPresenter
    @EnvironmentObject private var toast: ToastCenter

    @Environment(\.managedObjectContext) private var context

    @SectionedFetchRequest<Date, Event>(
        sectionIdentifier: \.groupStart,
        sortDescriptors: [SortDescriptor(\.start, order: .reverse)]
    ) private var sections: SectionedFetchResults<Date, Event>

    @State private var hiddenCount = 0
    @State private var searchText = ""

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 22, pinnedViews: [.sectionHeaders]) {
                if sections.isEmpty {
                    EmptyStateView(
                        emoji: "🗒️",
                        title: "Nothing here yet",
                        message: "Everything you log shows up here, grouped by day. Try holding a tile on the home screen."
                    )
                    .padding(.top, 40)
                }

                ForEach(sections) { section in
                    Section {
                        VStack(spacing: 10) {
                            ForEach(Array(section.enumerated()), id: \.element.objectID) { index, event in
                                TimelineRow(
                                    event: event,
                                    isFirst: index == 0,
                                    isLast: index == section.count - 1
                                )
                                .contextMenu {
                                    Button(role: .destructive) {
                                        delete(event)
                                    } label: {
                                        Label("Delete entry", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    } header: {
                        JournalDayHeader(date: section.id, count: section.count)
                    }
                }

                if hiddenCount > 0 {
                    lockedHistoryBanner
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .softScrollEdges()
        .animation(Motion.arrive, value: sections.count)
        .onAppear(perform: applyHistoryWindow)
        .onChange(of: subscriptions.isSubscribed) { _, _ in applyHistoryWindow() }
        .onChange(of: baby?.id) { _, _ in applyHistoryWindow() }
    }

    // MARK: - Free tier window

    /// Rewrites the fetch predicate whenever the selected baby or the entitlement
    /// changes, and counts what is being held back so we can be specific about it.
    private func applyHistoryWindow() {
        if subscriptions.isUnlocked(.fullHistory) {
            sections.nsPredicate = eventsBelongTo(baby)
            hiddenCount = 0
        } else {
            let horizon = FreeTier.journalHorizon
            sections.nsPredicate = eventPredicate(baby: baby, since: horizon)
            hiddenCount = countEvents(for: baby, before: horizon, in: context)
        }
    }

    private var lockedHistoryBanner: some View {
        Button {
            paywall.present(for: .fullHistory)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.title3)
                    .foregroundStyle(Palette.gold)

                VStack(alignment: .leading, spacing: 3) {
                    Text("\(hiddenCount) older \(hiddenCount == 1 ? "entry" : "entries") are waiting")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Palette.ink)
                    Text("The free plan keeps the last \(FreeTier.journalHistoryDays) days. BabyPlus+ keeps everything.")
                        .font(.caption)
                        .foregroundStyle(Palette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 4)
                ProBadge(compact: true)
            }
            .glassCard(radius: Radius.medium, padding: 16)
            .overlay(ShineOverlay().clipShape(RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)))
        }
        .buttonStyle(.pressable)
        .padding(.top, 6)
    }

    // MARK: - Actions

    private func delete(_ event: Event) {
        // Core Data has no cheap "undelete", so instead of offering an undo we make
        // the destruction explicit: it only ever happens from a context menu.
        withAnimation(Motion.snappy) {
            eventService.delete(events: [event])
        }
        Haptics.warning()
        toast.show(message: "Entry deleted", systemImage: "trash.fill", tint: .red)
    }
}

// MARK: - Day header

private struct JournalDayHeader: View {
    let date: Date
    let count: Int

    private var label: String {
        if Calendar.current.isDateInToday(date) { return "Today" }
        if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Palette.ink)

            Text("\(count)")
                .font(.caption2.weight(.bold))
                .foregroundStyle(Palette.inkSoft)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Palette.hairline, in: Capsule())

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .liquidGlass(.regular, in: Capsule())
        .padding(.vertical, 4)
    }
}

#if DEBUG
#Preview {
    ZStack {
        AuroraBackground()
        JournalView(baby: nil)
            .mockedDependencies()
            .environmentObject(SubscriptionService())
            .environmentObject(PaywallPresenter())
            .environmentObject(ToastCenter())
    }
}
#endif
