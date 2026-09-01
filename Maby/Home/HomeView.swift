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
    /// The baby every read and write on this screen is scoped to.
    let baby: Baby?

    @EnvironmentObject private var preferences: AppPreferences
    @EnvironmentObject private var subscriptions: SubscriptionService
    @EnvironmentObject private var toast: ToastCenter
    @EnvironmentObject private var paywall: PaywallPresenter

    @Environment(\.managedObjectContext) private var context

    @State private var sheet: EventType?
    @State private var showingEditBaby = false
    @State private var showingAddBaby = false
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
                    baby: baby,
                    stats: todayStats,
                    accent: preferences.effectiveAccent(isSubscribed: subscriptions.isSubscribed),
                    onEdit: { showingEditBaby = true },
                    onAddBaby: addAnotherBaby
                )

                if timer.isRunning, let session = timer.session {
                    LiveSessionCapsule(
                        session: session,
                        elapsed: timer.elapsed,
                        onStop: stopSession,
                        onCancel: {
                            withAnimation(Motion.snappy) { timer.cancel() }
                            Haptics.warning()
                        }
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
        .onChange(of: baby?.id) { _, _ in refreshStats() }
        .onReceive(databaseUpdates) { _ in refreshStats() }
        .sheet(item: $sheet) { type in
            AddEventSheet(type: type, baby: baby, timer: timer)
        }
        .sheet(isPresented: $showingEditBaby) {
            if let baby {
                EditBabyDetailsView(baby: baby)
            }
        }
        .sheet(isPresented: $showingAddBaby) {
            AddBabyView()
                .presentationBackground(.regularMaterial)
                .presentationCornerRadius(32)
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
                baby: baby,
                instantLog: {
                    guard baby != nil else { return .failed }
                    let breast = NursingEvent.Breast(rawValue: Int32(defaultBreast)) ?? .left
                    withAnimation(Motion.arrive) {
                        timer.start(.nursing(breast))
                        Haptics.tap(.medium)
                    }
                    return .startedSession
                },
                openDetails: { sheet = .nursing },
                showsTimerHint: true
            )

            QuickLogTile<BottleFeedEvent>(
                style: .bottle,
                baby: baby,
                instantLog: {
                    log { eventService.addBottle(for: baby, amount: defaultBottleMl) }
                },
                openDetails: { sheet = .bottle },
                instantLogMessage: "\(defaultBottleMl) mL bottle logged"
            )

            QuickLogTile<DiaperEvent>(
                style: .diaper,
                baby: baby,
                instantLog: {
                    let type = DiaperEvent.DiaperType(rawValue: Int32(defaultDiaperType)) ?? .wet
                    return log { eventService.addDiaperChange(for: baby, type: type) }
                },
                openDetails: { sheet = .diaper },
                instantLogMessage: "Diaper change logged"
            )

            QuickLogTile<SleepEvent>(
                style: .sleep,
                baby: baby,
                instantLog: {
                    guard baby != nil else { return .failed }
                    withAnimation(Motion.arrive) {
                        timer.start(.sleep)
                        Haptics.tap(.medium)
                    }
                    return .startedSession
                },
                openDetails: { sheet = .sleep },
                showsTimerHint: true
            )

            QuickLogTile<VomitEvent>(
                style: .vomit,
                baby: baby,
                instantLog: {
                    log { eventService.addVomit(for: baby, quantity: .medium) }
                },
                openDetails: { sheet = .vomit },
                instantLogMessage: "Spit-up logged"
            )
        }
    }

    // MARK: - Actions

    /// Adapts a service call into the outcome a quick-log tile reacts to.
    private func log<E: Event>(_ write: () -> Result<E, AddError>) -> InstantLogResult {
        switch write() {
        case .success(let event): return .logged(event)
        case .failure: return .failed
        }
    }

    private func stopSession() {
        guard let saved = timer.stopAndSave(for: baby) else {
            Haptics.error()
            return
        }
        Haptics.success()
        toast.show(
            message: "Session saved",
            tint: Palette.brand,
            undo: { EventUndo.delete(saved) }
        )
        bumpReminders(for: saved)
    }

    private func refreshStats() {
        todayStats = statistics.today(for: baby)
    }

    /// Adding a second profile is where the free plan stops, so the button either
    /// opens the form or explains why it can't.
    private func addAnotherBaby() {
        if BabyLimit.canAdd(current: babyCount(in: context), isSubscribed: subscriptions.isSubscribed) {
            showingAddBaby = true
        } else {
            paywall.present(for: .multipleBabies)
        }
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
    /// Whose log the new entry belongs to.
    let baby: Baby?
    @ObservedObject var timer: LiveSessionTimer

    var body: some View {
        Group {
            switch type {
            case .bottle: AddBottleFeedEventView(baby: baby)
            case .diaper: AddDiaperEventView(baby: baby)
            case .nursing: AddNursingEventView(baby: baby)
            case .sleep: AddSleepEventView(baby: baby)
            case .vomit: AddVomitEventView(baby: baby)
            case .nursingTimer: AddNursingEventView(baby: baby)
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
