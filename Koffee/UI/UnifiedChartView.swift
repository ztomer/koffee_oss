import SwiftUI
import Charts

/// Caffeine timeline chart: current level, bedtime projection, safe-limit
/// rule and optimal focus window. All values derive from logged caffeine
/// doses plus today's pending caffeine plan items.
struct CaffeineTimelineChart: View {
    let doses: [Dose]
    let wakeTime: Date
    let sleepTime: Date
    let safeLimit: Double

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
            metabolism: MetabolismRate.medium
        )
    }

    /// Caffeine level as percent of the safe bedtime limit.
    private var normalizedData: [(time: Date, percent: Double, mg: Double)] {
        guard safeLimit > 0 else { return [] }
        return unifiedData.map { point in
            let mg = point.compoundLevels[NootropicCompound.caffeine.rawValue] ?? point.totalLevel
            return (point.time, mg / safeLimit * 100, mg)
        }
    }

    private var maxYValue: Double {
        let overallMax = normalizedData.map { $0.percent }.max() ?? 30
        return max(30, overallMax)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if normalizedData.isEmpty {
                emptyStateView
            } else {
                chartView
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
        let data = normalizedData
        let yMax = maxYValue

        let chartStart = data.first?.time ?? wakeTime
        let chartEnd = data.last?.time ?? sleepTime.addingTimeInterval(3600 * 4)

        return Chart {
            ForEach(data, id: \.time) { point in
                if point.percent > 0 {
                    LineMark(
                        x: .value("Time", point.time),
                        y: .value("Level", point.percent),
                        series: .value("Compound", NootropicCompound.caffeine.rawValue)
                    )
                    .foregroundStyle(.orange)
                    .lineStyle(StrokeStyle(lineWidth: 3))
                }
            }

            RuleMark(y: .value("Safe Limit", 100))
                .foregroundStyle(.red.opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))

            if yMax > 100 {
                RectangleMark(
                    xStart: .value("Start", wakeTime),
                    xEnd: .value("End", sleepTime),
                    yStart: .value("Limit", 100),
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
            let steps = stride(from: 0, through: yMax, by: 25).map { $0 }
            AxisMarks(values: steps) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let percent = value.as(Double.self) {
                        Text("\(Int(percent))%")
                            .font(.system(size: 9))
                    }
                }
            }
        }
        .chartLegend(position: .bottom, alignment: .center, spacing: 10) {
            HStack(spacing: 4) {
                Circle()
                    .fill(.orange)
                    .frame(width: 8, height: 8)
                Text(NootropicCompound.caffeine.rawValue)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var currentStatusView: some View {
        let now = Date()
        let currentData = normalizedData.first { $0.time >= now } ?? normalizedData.last
        let currentCaffeine = currentData?.mg ?? 0
        let bedtimeData = normalizedData.last { $0.time <= sleepTime } ?? normalizedData.last
        let bedtimeCaffeine = bedtimeData?.mg ?? 0

        // Calculate peak time (caffeine peaks at ~45 min)
        let peakTime = doses.first?.time?.addingTimeInterval(45 * 60) ?? Date()
        let isPeakPast = peakTime < Date()

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
