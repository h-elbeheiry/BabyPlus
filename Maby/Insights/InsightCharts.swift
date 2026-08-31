import Charts
import MabyKit
import SwiftUI

/// The chart vocabulary for the Insights tab.
///
/// Each chart takes a plain `[DailyStat]`, which is what lets the onboarding show
/// a real, correctly-styled chart from sample data instead of a picture of one.

// MARK: - Feeds per day

struct FeedsChart: View {
    let days: [DailyStat]
    var height: CGFloat = 180
    var showsAxes = true

    var body: some View {
        Chart {
            ForEach(days) { day in
                BarMark(
                    x: .value("Day", day.day, unit: .day),
                    y: .value("Feeds", day.nursingSessions)
                )
                .foregroundStyle(by: .value("Kind", "Nursing"))
                .cornerRadius(4)

                BarMark(
                    x: .value("Day", day.day, unit: .day),
                    y: .value("Feeds", day.bottleFeeds)
                )
                .foregroundStyle(by: .value("Kind", "Bottle"))
                .cornerRadius(4)
            }
        }
        .chartForegroundStyleScale([
            "Nursing": EventStyle.nursing.tint,
            "Bottle": EventStyle.bottle.tint
        ])
        .chartLegend(position: .top, alignment: .leading, spacing: 8)
        .chartAxis(showsAxes)
        .frame(height: height)
    }
}

// MARK: - Sleep

struct SleepChart: View {
    let days: [DailyStat]
    var height: CGFloat = 180
    var showsAxes = true

    var body: some View {
        Chart(days) { day in
            AreaMark(
                x: .value("Day", day.day, unit: .day),
                y: .value("Hours", day.sleepHours)
            )
            .interpolationMethod(.monotone)
            .foregroundStyle(
                LinearGradient(
                    colors: [EventStyle.sleep.tint.opacity(0.45), EventStyle.sleep.tint.opacity(0.02)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            LineMark(
                x: .value("Day", day.day, unit: .day),
                y: .value("Hours", day.sleepHours)
            )
            .interpolationMethod(.monotone)
            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
            .foregroundStyle(EventStyle.sleep.tint)
        }
        .chartAxis(showsAxes)
        .frame(height: height)
    }
}

// MARK: - Diapers

struct DiaperChart: View {
    let days: [DailyStat]
    var height: CGFloat = 180
    var showsAxes = true

    private struct Slice: Identifiable {
        let id = UUID()
        let day: Date
        let kind: String
        let count: Int
    }

    private var slices: [Slice] {
        days.flatMap { day in
            [
                Slice(day: day.day, kind: "Wet", count: day.wetDiapers),
                Slice(day: day.day, kind: "Dirty", count: day.dirtyDiapers),
                Slice(day: day.day, kind: "Mixed", count: day.mixedDiapers),
                Slice(day: day.day, kind: "Clean", count: day.cleanDiapers)
            ]
        }
    }

    var body: some View {
        Chart(slices) { slice in
            BarMark(
                x: .value("Day", slice.day, unit: .day),
                y: .value("Changes", slice.count)
            )
            .foregroundStyle(by: .value("Kind", slice.kind))
            .cornerRadius(3)
        }
        .chartForegroundStyleScale([
            "Wet": EventStyle.diaper.tint,
            "Dirty": EventStyle.vomit.tint,
            "Mixed": EventStyle.timer.tint,
            "Clean": Palette.inkSoft.opacity(0.5)
        ])
        .chartLegend(position: .top, alignment: .leading, spacing: 8)
        .chartAxis(showsAxes)
        .frame(height: height)
    }
}

// MARK: - Bottle volume

struct VolumeChart: View {
    let days: [DailyStat]
    var height: CGFloat = 180
    var showsAxes = true

    var body: some View {
        Chart(days) { day in
            LineMark(
                x: .value("Day", day.day, unit: .day),
                y: .value("mL", day.bottleMilliliters)
            )
            .interpolationMethod(.catmullRom)
            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
            .foregroundStyle(EventStyle.bottle.tint)

            PointMark(
                x: .value("Day", day.day, unit: .day),
                y: .value("mL", day.bottleMilliliters)
            )
            .foregroundStyle(EventStyle.bottle.tint)
            .symbolSize(28)
        }
        .chartAxis(showsAxes)
        .frame(height: height)
    }
}

// MARK: - Shared axis styling

private extension View {
    /// Charts inside glass need very quiet axes, and the compact previews need
    /// none at all.
    @ViewBuilder
    func chartAxis(_ shows: Bool) -> some View {
        if shows {
            self
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                            .font(.caption2)
                            .foregroundStyle(Palette.inkSoft)
                        AxisGridLine().foregroundStyle(Palette.hairline.opacity(0.5))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
                        AxisValueLabel()
                            .font(.caption2)
                            .foregroundStyle(Palette.inkSoft)
                        AxisGridLine().foregroundStyle(Palette.hairline.opacity(0.5))
                    }
                }
        } else {
            self
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .chartLegend(.hidden)
        }
    }
}

/// Plausible-looking data for previews and for the onboarding walkthrough. It is
/// deliberately not behind `#if DEBUG` — the onboarding ships with it, because
/// showing a new user an empty chart teaches them nothing.
enum SampleStats {
    static func week() -> [DailyStat] {
        let today = Calendar.current.startOfDay(for: .now)
        let nursing = [5, 6, 4, 7, 5, 6, 5]
        let bottles = [2, 1, 3, 1, 2, 2, 3]
        let sleep = [13.5, 12.0, 14.2, 11.8, 13.0, 14.5, 12.6]
        let wet = [4, 5, 4, 6, 5, 4, 5]
        let dirty = [2, 1, 3, 2, 2, 3, 1]

        return (0..<7).compactMap { index in
            guard let day = Calendar.current.date(byAdding: .day, value: index - 6, to: today) else { return nil }
            return DailyStat(
                day: day,
                bottleMilliliters: bottles[index] * 120,
                bottleFeeds: bottles[index],
                nursingSessions: nursing[index],
                nursingSeconds: nursing[index] * 16 * 60,
                sleepSeconds: Int(sleep[index] * 3600),
                sleepSessions: 4,
                wetDiapers: wet[index],
                dirtyDiapers: dirty[index],
                mixedDiapers: 1,
                cleanDiapers: 0,
                spitUps: index % 3
            )
        }
    }
}

#if DEBUG
#Preview {
    ZStack {
        AuroraBackground()
        VStack(spacing: 16) {
            FeedsChart(days: SampleStats.week()).glassCard()
            SleepChart(days: SampleStats.week()).glassCard()
        }
        .padding()
    }
}
#endif
