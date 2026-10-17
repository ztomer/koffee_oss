import SwiftUI
import Charts

/// Caffeine timeline chart: current level, bedtime projection, safe-limit
/// rule and optimal focus window. All values derive from THE ruled dose set
/// (L4): logged caffeine doses plus today's pending caffeine plan items,
/// deduplicated when the planned dose was already logged (`effectiveDoseSet`).
struct CaffeineTimelineChart: View {
    let doses: [Dose]
    let wakeTime: Date
    let sleepTime: Date
    let safeLimit: Double
    let metabolism: MetabolismRate

    @State private var selectedTime: Date?

    private var doseTuples: [(Date, Double)] {
        doses.compactMap { d -> (Date, Double)? in
            guard let time = d.time, d.amount > 0 else { return nil }
            return (time, d.amount)
        }
    }

    private var focusWindow: FocusWindow? {
        guard !doseTuples.isEmpty else { return nil }
        return calculateOptimalFocusWindow(doses: doseTuples, threshold: 50)
    }

    private var unifiedData: [UnifiedCurvePoint] {
        let endTime = sleepTime.addingTimeInterval(3600 * 4)
        return generateUnifiedCurvePoints(
            doses: doseTuples,
            from: wakeTime,
            to: endTime,
            metabolism: metabolism
        )
    }

    /// Chart points in milligrams — the Y axis speaks mg, never percent-of-what.
    private var chartData: [(time: Date, mg: Double)] {
        unifiedData.map { point in
            let mg = point.compoundLevels[NootropicCompound.caffeine.rawValue] ?? point.totalLevel
            return (point.time, mg)
        }
    }

    private var maxYValue: Double {
        let overallMax = chartData.map { $0.mg }.max() ?? 60
        return max(60, max(overallMax, safeLimit * 1.2))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if chartData.isEmpty {
                emptyStateView
            } else {
                chartView
                chartLegendView
            }

            currentStatusView
        }
        .padding(10)
        .background(Color.clear)
        .clipShape(.rect(cornerRadius: 12))
    }

    private var emptyStateView: some View {
        Text("Add caffeine doses to see timeline")
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var chartView: some View {
        let data = chartData
        let yMax = maxYValue

        let chartStart = data.first?.time ?? wakeTime
        let chartEnd = data.last?.time ?? sleepTime.addingTimeInterval(3600 * 4)

        return Chart {
            ForEach(data, id: \.time) { point in
                if point.mg > 0 {
                    LineMark(
                        x: .value("Time", point.time),
                        y: .value("Caffeine", point.mg),
                        series: .value("Compound", NootropicCompound.caffeine.rawValue)
                    )
                    .foregroundStyle(.orange)
                    .lineStyle(StrokeStyle(lineWidth: 3))
                }
            }

            RuleMark(y: .value("Sleep limit", safeLimit))
                .foregroundStyle(.red.opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))

            if yMax > safeLimit {
                RectangleMark(
                    xStart: .value("Start", wakeTime),
                    xEnd: .value("End", sleepTime),
                    yStart: .value("Limit", safeLimit),
                    yEnd: .value("Max", yMax)
                )
                .foregroundStyle(.red.opacity(0.05))
            }

            // Focus window rectangle
            if let window = focusWindow, window.start < window.end {
                RectangleMark(
                    xStart: .value("Start", window.start),
                    xEnd: .value("End", window.end),
                    yStart: .value("Y", 0),
                    yEnd: .value("Y", yMax)
                )
                .foregroundStyle(.green.opacity(0.15))
            }
        }
        .chartXScale(domain: chartStart...chartEnd)
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 2)) { value in
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(formatHour(date))
                            .font(.system(size: 9))
                    }
                }
            }
        }
        .chartYScale(domain: 0...yMax)
        .chartYAxis {
            let step = yMax > 150 ? 50.0 : 25.0
            let steps = stride(from: 0, through: yMax, by: step).map { $0 }
            AxisMarks(values: steps) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let mg = value.as(Double.self) {
                        Text("\(Int(mg))")
                            .font(.system(size: 9))
                    }
                }
            }
        }
    }

    /// Plain-SwiftUI legend: every region and line gets a swatch plus words,
    /// so no distinction rides on hue alone and nothing can clip off-canvas.
    private var chartLegendView: some View {
        HStack(spacing: 12) {
            HStack(spacing: 4) {
                Circle()
                    .fill(.orange)
                    .frame(width: 8, height: 8)
                Text(NootropicCompound.caffeine.rawValue)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 2)
                    .stroke(.red.opacity(0.7), style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                    .frame(width: 12, height: 8)
                Text("Sleep limit \(Int(safeLimit))mg")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(.red.opacity(0.25))
                    .frame(width: 8, height: 8)
                Text("Over sleep limit")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(.green.opacity(0.4))
                    .frame(width: 8, height: 8)
                Text("Best focus")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 2)
    }

    /// The instant the row annotates as the day's peak: where the drawn curve is highest.
    ///
    /// This used to be `doses.first?.time` plus a 45-minute absorption allowance, which named the
    /// *earliest* dose's peak — so a later, larger dose left the label behind (L5: the row printed
    /// "Peak 07:45" under a curve that topped out at 15:00). `Current Caffeine` and `At Bedtime` on
    /// the same row are read off this curve, and the peak is derived from it now too. The model has
    /// no absorption term (`calculateCaffeineLevel` is pure decay), so if one is ever added the
    /// label follows it rather than needing another allowance here.
    ///
    /// Exposed rather than private so a test can assert the value instead of reading it off a
    /// rendered label.
    var peakInstant: Date? {
        guard !doses.isEmpty else { return nil }
        return chartData.max { $0.mg < $1.mg }?.time
    }

    /// The row's "Current Caffeine" value: the curve at the one clock door. Exposed rather than
    /// private so a test can assert it, like `peakInstant`.
    var currentCaffeine: Double {
        let now = DateHelper.now
        let currentData = chartData.first { $0.time >= now } ?? chartData.last
        return currentData?.mg ?? 0
    }

    /// The row's "At Bedtime" value: THE funnel at this day's bedtime, not the curve.
    ///
    /// L4 (owner-ruled): the row used to read the curve's value at `sleepTime`, which is
    /// `projectBedtimeCaffeine` with its day-boundary rule stripped out — for a plan item landed
    /// exactly at wake the two differ (the curve counts it decaying today; the funnel moves it to
    /// the coming day), and the dashboard then carried two bedtime numbers. One bedtime number:
    /// the row calls the funnel, the banner calls the funnel, the tank calls the funnel.
    /// Exposed rather than private so a test can assert the value, like `currentCaffeine`.
    var bedtimeCaffeineLevel: Double {
        projectBedtimeCaffeine(
            doses: doseTuples,
            wakeTime: wakeTime,
            sleepTime: sleepTime,
            metabolism: metabolism
        )
    }

    private var currentStatusView: some View {
        let bedtimeCaffeine = bedtimeCaffeineLevel

        let peakTime = peakInstant ?? DateHelper.now
        let isPeakPast = peakTime < DateHelper.now

        return HStack(spacing: 16) {
            VStack(alignment: .leading) {
                Text("Current Caffeine")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("\(Int(currentCaffeine))mg")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundStyle(.orange)
            }

            Divider().frame(height: 30)

            VStack(alignment: .leading) {
                Text("At Bedtime")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("\(Int(bedtimeCaffeine))mg")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundStyle(bedtimeCaffeine > 50 ? .red : .green)
            }

            if !doses.isEmpty {
                Divider().frame(height: 30)

                VStack(alignment: .leading) {
                    Text(isPeakPast ? "Peak" : "Peak At")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(formatTime(peakTime))
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(.purple)
                }
            }
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func formatHour(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
