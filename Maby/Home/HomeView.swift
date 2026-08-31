import CoreData
import Factory
import MabyKit
import SwiftUI

/// The screen the app opens on: who you're tracking, how today has gone so far,
/// and five ways to log something in under a second.
struct HomeView: View {
    @Injected(Container.eventService) private var eventService
    @Injected(Container.statisticsService) private var statistics

    @ObservedObject var timer: LiveSessionTimer

    @EnvironmentObject private var preferences: AppPreferences
    @EnvironmentObject private var subscriptions: SubscriptionService
    @EnvironmentObject private var toast: ToastCenter

    @State private var sheet: EventType?
    @State private var showingEditBaby = false
    @State private var todayStats: DailyStat?

    /// Remembered so a touch-and-hold repeats what you did last time rather than
    /// guessing.
    @AppStorage("babyplus.default.bottleMl") private var defaultBottleMl = 120
    @AppStorage("babyplus.default.diaperType") private var defaultDiaperType = 0
    @AppStorage("babyplus.default.breast") private var defaultBreast = 0

    private let databaseUpdates = NotificationCenter.default.publisher(
        for: .NSManagedObjectContextDidSave
    )

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                BabyHeroCard(
                    stats: todayStats,
                    accent: preferences.effectiveAccent(isSubscribed: subscriptions.isSubscribed),
                    onTap: { showingEditBaby = true }
                )

                if timer.isRunning, let session = timer.session {
                    LiveSessionCapsule(
                        session: session,
                        elapsed: timer.elapsed,
                        onStop: stopSession,
                        onCancel: { withAnimation(Motion.snappy) { timer.cancel() } }
                    )
                    .transition(.rise)
                }

                todayGlance

                VStack(alignment: .leading, spacing: 12) {
                    SectionTitle("Log something", subtitle: "Tap for details · hold to log it now")
                    quickLogGrid
                }

                if !subscriptions.isSubscribed {
                    ProUpsellRow(feature: .insights)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .softScrollEdges()
        .animation(Motion.arrive, value: timer.isRunning)
        .onAppear(perform: refreshStats)
        .onReceive(databaseUpdates) { _ in refreshStats() }
        .sheet(item: $sheet) { type in
            AddEventSheet(type: type, timer: timer)
        }
        .sheet(isPresented: $showingEditBaby) {
            EditBabyDetailsView()
        }
    }

    // MARK: - Today

    @ViewBuilder
    private var todayGlance: some View {
        let stats = todayStats ?? .empty(day: Calendar.current.startOfDay(for: .now))

        VStack(alignment: .leading, spacing: 12) {
            SectionTitle("Today so far")

            GlassStack(spacing: 14) {
                HStack(spacing: 10) {
                    StatTile(
                        value: "\(stats.feeds)",
                        caption: "feeds",
                        systemImage: "drop.fill",
                        tint: EventStyle.bottle.tint
                    )
                    StatTile(
                        value: stats.sleepSeconds > 0 ? TimeInterval(stats.sleepSeconds).compactDuration : "—",
                        caption: "sleep",
                        systemImage: "moon.stars.fill",
                        tint: EventStyle.sleep.tint
                    )
                    StatTile(
                        value: "\(stats.diaperChanges)",
                        caption: "changes",
                        systemImage: "circle.grid.2x2.fill",
                        tint: EventStyle.diaper.tint
                    )
                    StatTile(
                        value: stats.bottleMilliliters > 0 ? "\(stats.bottleMilliliters)" : "—",
                        caption: "mL bottle",
                        systemImage: "waterbottle.fill",
                        tint: EventStyle.nursing.tint
                    )
                }
            }
        }
    }

    // MARK: - Quick log

    private var quickLogGrid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            QuickLogTile<NursingEvent>(
                style: .nursing,
                instantLog: {
                    let breast = NursingEvent.Breast(rawValue: Int32(defaultBreast)) ?? .left
                    withAnimation(Motion.arrive) { timer.start(.nursing(breast)) }
                    return nil
                },
                openDetails: { sheet = .nursing },
                showsTimerHint: true
            )

            QuickLogTile<BottleFeedEvent>(
                style: .bottle,
                instantLog: {
                    try? eventService.addBottle(amount: defaultBottleMl).get()
                },
                openDetails: { sheet = .bottle },
                instantLogMessage: "\(defaultBottleMl) mL bottle logged"
            )

            QuickLogTile<DiaperEvent>(
                style: .diaper,
                instantLog: {
                    let type = DiaperEvent.DiaperType(rawValue: Int32(defaultDiaperType)) ?? .wet
                    return try? eventService.addDiaperChange(type: type).get()
                },
                openDetails: { sheet = .diaper },
                instantLogMessage: "Diaper change logged"
            )

            QuickLogTile<SleepEvent>(
                style: .sleep,
                instantLog: {
                    withAnimation(Motion.arrive) { timer.start(.sleep) }
                    return nil
                },
                openDetails: { sheet = .sleep },
                showsTimerHint: true
            )

            QuickLogTile<VomitEvent>(
                style: .vomit,
                instantLog: {
                    try? eventService.addVomit(quantity: .medium).get()
                },
                openDetails: { sheet = .vomit },
                instantLogMessage: "Spit-up logged"
            )
        }
    }

    // MARK: - Actions

    private func stopSession() {
        guard let saved = timer.stopAndSave() else { return }
        toast.show(
            message: "Session saved",
            tint: Palette.brand,
            undo: { EventUndo.delete(saved) }
        )
        bumpReminders(for: saved)
    }

    private func refreshStats() {
        todayStats = statistics.today()
    }

    /// Logging something pushes the matching reminder back, so a well-tracked day
    /// stays quiet.
    private func bumpReminders(for event: Event) {
        guard subscriptions.isUnlocked(.reminders) else { return }
        let reminders = Container.reminderService()
        let kind: ReminderService.Kind
        switch event {
        case is BottleFeedEvent, is NursingEvent: kind = .feeding
        case is DiaperEvent: kind = .diaper
        case is SleepEvent: kind = .sleep
        default: return
        }
        reminders.bump(
            kind,
            inHours: preferences.reminderInterval(kind),
            enabled: preferences.isReminderEnabled(kind)
        )
    }
}

// MARK: - Sheet routing

/// Routes an `EventType` to the right add-event sheet, with the presentation
/// details (height, glass background) applied in one place.
private struct AddEventSheet: View {
    let type: EventType
    @ObservedObject var timer: LiveSessionTimer

    var body: some View {
        Group {
            switch type {
            case .bottle: AddBottleFeedEventView()
            case .diaper: AddDiaperEventView()
            case .nursing: AddNursingEventView()
            case .sleep: AddSleepEventView()
            case .vomit: AddVomitEventView()
            case .nursingTimer: AddNursingEventView()
            }
        }
        .presentationDetents([.height(sheetHeight), .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(.regularMaterial)
        .presentationCornerRadius(32)
    }

    private var sheetHeight: CGFloat {
        switch type {
        case .nursing: return 560
        case .bottle: return 520
        default: return 470
        }
    }
}
