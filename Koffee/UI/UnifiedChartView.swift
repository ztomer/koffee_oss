import SwiftUI
import Charts

struct UnifiedNootropicChart: View {
    let doses: [Dose]
    let supplements: [NootropicCompound]
    let wakeTime: Date
    let sleepTime: Date
    let safeLimit: Double

    @State private var selectedTime: Date?

    private var activeInteractions: [(extensionHours: Double, description: String)] {
        // Build interactions from supplements in the chart
        let interactionModel = NootropicInteractionModel(compounds: supplements, caffeineDoseMg: 100)
        return interactionModel.activeInteractions.map { ($0.extensionHours, $0.description) }
    }

    private var focusWindow: FocusWindow? {
        let doseTuples = doses.compactMap { d -> (Date, Double)? in
            guard let time = d.time, d.amount > 0 else { return nil }
            return (time, d.amount)
        }
        guard !doseTuples.isEmpty else { return nil }
        return calculateOptimalFocusWindow(doses: doseTuples, threshold: 50)
    }

    private var unifiedData: [UnifiedCurvePoint] {
        let endTime = sleepTime.addingTimeInterval(3600 * 4)

        let filteredDoses = doses.compactMap { d -> (Date, Double)? in
            guard let time = d.time, d.amount > 0 else { return nil }
            return (time, d.amount)
        }

        return generateUnifiedCurvePoints(
            doses: filteredDoses,
            supplements: supplements,
            from: wakeTime,
            to: endTime,
            metabolism: MetabolismRate.medium,
            interactions: activeInteractions
        )
    }

    private var normalizedData: [NormalizedCurvePoint] {
        var safeLimits: [String: Double] = [:]

        for compound in supplements {
            safeLimits[compound.rawValue] = Double(compound.safeLimitMg)
        }

        return ChartNormalizer.normalize(unifiedData, safeLimits: safeLimits)
    }

    private var allCompounds: [String] {
        var compounds = [NootropicCompound.caffeine.rawValue]
        compounds.append(contentsOf: supplements.map { $0.rawValue })
        return compounds
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if unifiedData.isEmpty {
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

    private var headerSection: some View {
        HStack {
            Text("Unified Nootropic Timeline")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
            Spacer()
            if let time = selectedTime {
                Text(formatTime(time))
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.orange)
            }
        }
    }

    private var emptyStateView: some View {
        Text("Add caffeine doses to see timeline")
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var maxYValue: Double {
        // Find max percentage for each compound across all time points
        var maxPercentForEachCompound: [String: Double] = [:]

        for point in normalizedData {
            for compound in allCompounds {
                let level = point.level(for: compound)
                let currentMax = maxPercentForEachCompound[compound] ?? 0
                if level > currentMax {
                    maxPercentForEachCompound[compound] = level
                }
            }
        }

        // Find the overall maximum across all compounds
        let overallMax = maxPercentForEachCompound.values.max() ?? 30

        // Minimum 30% to prevent cutoff when data is small
        return max(30, overallMax)
    }

    private var chartView: some View {
        let count = normalizedData.count
        let compounds = allCompounds
        let yMax = maxYValue

        // Chart time domain - from first data point to last data point (extends past sleepTime)
        let chartStart = normalizedData.first?.time ?? wakeTime
        let chartEnd = normalizedData.last?.time ?? sleepTime.addingTimeInterval(3600 * 4)

        return Chart {
            chartLines(count: count, compounds: compounds)

            safeLimitRule

            if yMax > 100 {
                warningArea(wakeTime: wakeTime, sleepTime: sleepTime, yMax: yMax)
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
        .chartForegroundStyleScale(domain: compounds, range: compounds.map { compoundColor($0) })
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
            let c = compounds
            HStack(spacing: 12) {
                ForEach(c, id: \.self) { compound in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(compoundColor(compound))
                            .frame(width: 8, height: 8)
                        Text(compound)
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    @ChartContentBuilder
    private func chartLines(count: Int, compounds: [String]) -> some ChartContent {
        ForEach(0..<count, id: \.self) { i in
            let point = normalizedData[i]
            ForEach(compounds, id: \.self) { compound in
                let level = point.level(for: compound)
                if level > 0 {
                    let isCaffeine = compound == NootropicCompound.caffeine.rawValue
                    LineMark(
                        x: .value("Time", point.time),
                        y: .value("Level", level),
                        series: .value("Compound", compound)
                    )
                    .foregroundStyle(by: .value("Compound", compound))
                    .lineStyle(StrokeStyle(lineWidth: isCaffeine ? 3 : 2))
                }
            }
        }
    }

    private var safeLimitRule: some ChartContent {
        RuleMark(y: .value("Safe Limit", 100))
            .foregroundStyle(.red.opacity(0.5))
            .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
    }

    private func warningArea(wakeTime: Date, sleepTime: Date, yMax: Double) -> some ChartContent {
        RectangleMark(
            xStart: .value("Start", wakeTime),
            xEnd: .value("End", sleepTime),
            yStart: .value("Limit", 100),
            yEnd: .value("Max", yMax)
        )
        .foregroundStyle(.red.opacity(0.05))
    }

    private var supplementTimingLines: [(time: Date, name: String, color: Color)] {
        guard let firstDose = doses.first, let coffeeTime = firstDose.time else { return [] }

        var lines: [(time: Date, name: String, color: Color)] = []

        for supplement in supplements {
            let offset = supplement.recommendedTimingMinutes
            let time = coffeeTime.addingTimeInterval(offset * 60)
            lines.append((time: time, name: supplement.rawValue, color: compoundColor(supplement.rawValue)))
        }

        return lines.sorted { $0.time < $1.time }
    }

private var currentStatusView: some View {
        let currentData = unifiedData.first { $0.time >= Date() } ?? unifiedData.last
        let currentCaffeine = currentData?.compoundLevels[NootropicCompound.caffeine.rawValue] ?? 0
        let bedtimeData = unifiedData.last { $0.time <= sleepTime } ?? unifiedData.last
        let bedtimeCaffeine = bedtimeData?.compoundLevels[NootropicCompound.caffeine.rawValue] ?? 0

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

    private func compoundColor(_ compound: String) -> Color {
        colorForCompound(compound)
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

    private func bedtimeRiskColor(_ level: Double) -> Color {
        if level <= safeLimit * 0.5 { return .green }
        if level <= safeLimit { return .yellow }
        return .red
    }

    private func bedtimeRiskIcon(_ level: Double) -> String {
        if level <= safeLimit * 0.5 { return "moon.fill" }
        if level <= safeLimit { return "exclamationmark.triangle" }
        return "moon.zzz.fill"
    }
}
