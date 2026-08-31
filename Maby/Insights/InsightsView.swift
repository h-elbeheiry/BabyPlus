import Factory
import MabyKit
import SwiftUI

/// The premium analytics tab.
///
/// Free accounts still get here and still see their *own* numbers — blurred, with
/// an invitation on top — because a locked screen that shows nothing is easy to
/// dismiss and easy to forget.
struct InsightsView: View {
    @Injected(Container.statisticsService) private var statistics
    @Injected(Container.exportService) private var exporter

    @EnvironmentObject private var subscriptions: SubscriptionService
    @EnvironmentObject private var paywall: PaywallPresenter

    @FetchRequest(fetchRequest: allBabies)
    private var babies: FetchedResults<Baby>

    @State private var window: Window = .week
    @State private var days: [DailyStat] = []
    @State private var exportURL: URL?
    @State private var exportFailed = false

    /// Named `Window` rather than `Range` so it doesn't shadow the standard
    /// library's `Range` inside this type.
    enum Window: Int, CaseIterable, Identifiable {
        case week = 7, fortnight = 14, month = 30

        var id: Int { rawValue }
        var label: String {
            switch self {
            case .week: return "7 days"
            case .fortnight: return "14 days"
            case .month: return "30 days"
            }
        }
    }

    private var summary: StatsSummary { StatsSummary(days: days) }

    private let databaseUpdates = NotificationCenter.default.publisher(
        for: .NSManagedObjectContextDidSave
    )

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                rangePicker

                PremiumGate(feature: .insights) {
                    VStack(alignment: .leading, spacing: 22) {
                        averagesRow
                        chartCard(
                            title: "Feeding",
                            subtitle: "Nursing sessions and bottles per day",
                            trend: summary.feedTrend
                        ) {
                            FeedsChart(days: days)
                        }
                        chartCard(
                            title: "Sleep",
                            subtitle: "Hours slept per day",
                            trend: summary.sleepTrend
                        ) {
                            SleepChart(days: days)
                        }
                        chartCard(
                            title: "Diapers",
                            subtitle: "Changes per day by kind",
                            trend: nil
                        ) {
                            DiaperChart(days: days)
                        }
                        chartCard(
                            title: "Bottle volume",
                            subtitle: "Millilitres per day",
                            trend: nil
                        ) {
                            VolumeChart(days: days)
                        }
                    }
                }
                .animation(Motion.arrive, value: subscriptions.isSubscribed)

                exportRow
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .softScrollEdges()
        .onAppear(perform: reload)
        .onChange(of: window) { _, _ in reload() }
        .onReceive(databaseUpdates) { _ in reload() }
        .sheet(item: Binding(
            get: { exportURL.map { ShareItem(url: $0) } },
            set: { if $0 == nil { exportURL = nil } }
        )) { item in
            ShareSheet(items: [item.url])
                .presentationDetents([.medium, .large])
        }
        .alert("We couldn't build that file", isPresented: $exportFailed) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("There's nothing to export yet — log a few entries first.")
        }
    }

    // MARK: - Pieces

    private var rangePicker: some View {
        Picker("Range", selection: $window) {
            ForEach(Window.allCases) { option in
                Text(option.label).tag(option)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: window) { _, _ in Haptics.selection() }
    }

    private var averagesRow: some View {
        GlassStack(spacing: 14) {
            HStack(spacing: 10) {
                StatTile(
                    value: summary.averageFeedsPerDay.formatted(.number.precision(.fractionLength(1))),
                    caption: "feeds / day",
                    systemImage: "drop.fill",
                    tint: EventStyle.bottle.tint
                )
                StatTile(
                    value: summary.averageSleepHours.formatted(.number.precision(.fractionLength(1))) + "h",
                    caption: "sleep / day",
                    systemImage: "moon.stars.fill",
                    tint: EventStyle.sleep.tint
                )
                StatTile(
                    value: summary.averageDiapersPerDay.formatted(.number.precision(.fractionLength(1))),
                    caption: "changes / day",
                    systemImage: "circle.grid.2x2.fill",
                    tint: EventStyle.diaper.tint
                )
            }
        }
    }

    private func chartCard<Content: View>(
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey,
        trend: Double?,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title, subtitle: subtitle) {
                if let trend { TrendPill(change: trend) }
            }
            content()
        }
        .glassCard(padding: 16)
    }

    private var exportRow: some View {
        Group {
            if subscriptions.isUnlocked(.dataExport) {
                Button(action: export) {
                    Label("Export everything as a spreadsheet", systemImage: "square.and.arrow.up")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .glassButtonStyle()
                .controlSize(.large)
            } else {
                ProUpsellRow(feature: .dataExport)
            }
        }
    }

    // MARK: - Actions

    private func reload() {
        days = statistics.dailyStats(forLast: window.rawValue)
    }

    private func export() {
        do {
            exportURL = try exporter.writeCSV(babyName: babies.first?.name)
            Haptics.success()
        } catch {
            exportFailed = true
            Haptics.error()
        }
    }
}

// MARK: - Trend pill

/// "+12%" with an arrow — the second half of a window compared with the first.
struct TrendPill: View {
    let change: Double

    private var isUp: Bool { change >= 0 }

    var body: some View {
        let percent = Int((abs(change) * 100).rounded())
        return HStack(spacing: 3) {
            Image(systemName: isUp ? "arrow.up.right" : "arrow.down.right")
                .font(.caption2.weight(.bold))
            Text("\(percent)%")
                .font(.caption.weight(.semibold).monospacedDigit())
        }
        .foregroundStyle(isUp ? EventStyle.diaper.tint : EventStyle.timer.tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background((isUp ? EventStyle.diaper.tint : EventStyle.timer.tint).opacity(0.14), in: Capsule())
        .accessibilityLabel(isUp ? "Up \(percent) percent" : "Down \(percent) percent")
    }
}

// MARK: - Sharing

private struct ShareItem: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

/// `UIActivityViewController` still gives the best export experience for a file
/// the user is going to hand to someone else.
private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) { }
}

#if DEBUG
#Preview {
    ZStack {
        AuroraBackground()
        InsightsView()
            .mockedDependencies()
            .environmentObject(SubscriptionService())
            .environmentObject(PaywallPresenter())
    }
}
#endif
