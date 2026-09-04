import SwiftUI
import Charts

struct PKCurveView: View {
    let curveData: [PKCurvePoint]
    let focusWindow: FocusWindow?
    let bedtimeLevel: Double
    let safeLimit: Double

    @State private var selectedPoint: PKCurvePoint?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Caffeine Level")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                if let point = selectedPoint {
                    Text("\(Int(point.expected))mg")
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.orange)
                }
            }

            if curveData.isEmpty {
                Text("Add doses to see curve")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(height: 150)
                    .frame(maxWidth: .infinity)
            } else {
                let chartData = curveData
                let safeLevel = safeLimit

                Chart(chartData) { point in
                    AreaMark(
                        x: .value("Time", point.time),
                        yStart: .value("Lower", point.lower),
                        yEnd: .value("Upper", point.upper)
                    )
                    .foregroundStyle(.orange.opacity(0.15))

                    LineMark(
                        x: .value("Time", point.time),
                        y: .value("Level", point.expected)
                    )
                    .foregroundStyle(.orange)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }
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
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let mg = value.as(Double.self) {
                                Text("\(Int(mg))")
                                    .font(.system(size: 9))
                            }
                        }
                    }
                }
                .chartYScale(domain: 0...(max(curveData.map { $0.upper }.max() ?? 200, safeLevel * 1.5)))
                .frame(height: 150)
            }

            HStack {
                VStack(alignment: .leading) {
                    Text("Current")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text("\(Int(currentLevel))mg")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(.orange)
                }

                Spacer()

                VStack(alignment: .trailing) {
                    Text("At Bedtime")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                    HStack(spacing: 4) {
                        Text("\(Int(bedtimeLevel))mg")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundStyle(bedtimeLevelColor)
                        Image(systemName: bedtimeIcon)
                            .foregroundStyle(bedtimeLevelColor)
                            .font(.system(size: 12))
                    }
                }
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(.rect(cornerRadius: 12))
    }

    private var currentLevel: Double {
        curveData.first?.expected ?? 0
    }

    private var bedtimeLevelColor: Color {
        if bedtimeLevel <= safeLimit * 0.5 { return .green }
        if bedtimeLevel <= safeLimit { return .yellow }
        return .red
    }

    private var bedtimeIcon: String {
        if bedtimeLevel <= safeLimit * 0.5 { return "moon.fill" }
        if bedtimeLevel <= safeLimit { return "exclamationmark.triangle" }
        return "moon.zzz.fill"
    }

    private func formatHour(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func selectPoint(at location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) {
        let xPosition = location.x - geometry[proxy.plotFrame!].origin.x
        guard let date: Date = proxy.value(atX: xPosition) else { return }

        selectedPoint = curveData.min(by: { abs($0.time.timeIntervalSince(date)) < abs($1.time.timeIntervalSince(date)) })
    }
}

struct NootropicTimelineView: View {
    let doses: [Dose]
    let stack: [NootropicCompound]
    let wakeTime: Date
    let sleepTime: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Nootropic Stack Timeline")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                if !stack.isEmpty {
                    Text("\(stack.count) active")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(.green.opacity(0.2))
                        .clipShape(.capsule)
                }
            }

            if doses.isEmpty {
                Text("Add doses to see timeline")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(height: 120)
                    .frame(maxWidth: .infinity)
            } else {
                let timelineData = generateTimelineData()

                Chart {
                    ForEach(timelineData, id: \.id) { item in
                        LineMark(
                            x: .value("Time", item.time),
                            y: .value("Level", item.level),
                            series: .value("Compound", item.compound)
                        )
                        .foregroundStyle(colorForCompound(item.compound))
                        .lineStyle(StrokeStyle(lineWidth: item.isMainCompound ? 3 : 2))
                    }

                    if let window = calculateFocusWindow() {
                        RectangleMark(
                            xStart: .value("Start", window.start),
                            xEnd: .value("End", window.end),
                            yStart: .value("Y", 0),
                            yEnd: .value("Y", 120)
                        )
                        .foregroundStyle(.green.opacity(0.15))
                    }
                }
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
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let level = value.as(Double.self) {
                                Text("\(Int(level))")
                                    .font(.system(size: 9))
                            }
                        }
                    }
                }
                .chartYScale(domain: 0...130)
                .frame(height: 120)
            }

            if !stack.isEmpty {
                stackLegend
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(.rect(cornerRadius: 12))
    }

    private var stackLegend: some View {
        HStack(spacing: 12) {
            ForEach(stack, id: \.self) { compound in
                HStack(spacing: 4) {
                    Circle()
                        .fill(colorForCompound(compound.rawValue))
                        .frame(width: 8, height: 8)
                    Text(compound.rawValue)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // Note: This local function is duplicated for convenience but should match colorForCompound in UIComponents.swift
    private func colorForCompound(_ compound: String) -> Color {
        switch compound.lowercased() {
        case "caffeine": return .orange
        case "l-theanine": return .blue
        case "magnesium": return .purple
        case "ashwagandha": return .green
        case "vitamin b": return .yellow
        case "rhodiola": return .orange.opacity(0.7)
        case "theacrine": return .cyan
        default: return .gray
        }
    }

    private func formatHour(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func generateTimelineData() -> [TimelinePoint] {
        var points: [TimelinePoint] = []
        let endTime = sleepTime.addingTimeInterval(3600 * 4)

        guard !doses.isEmpty else { return points }

        for dose in doses {
            guard let time = dose.time else { continue }

            points.append(TimelinePoint(
                id: UUID(),
                time: time,
                level: dose.amount,
                compound: "Caffeine",
                isMainCompound: true
            ))

            for i in stride(from: 0, to: 12, by: 1) {
                let t = time.addingTimeInterval(Double(i) * 1800)
                guard t <= endTime else { break }
                let hoursFromDose = Double(i) * 0.5
                let level = dose.amount * pow(0.5, hoursFromDose / 5.0)
                if level > 5 {
                    points.append(TimelinePoint(
                        id: UUID(),
                        time: t,
                        level: level,
compound: NootropicCompound.caffeine.rawValue,
                        isMainCompound: false
                    ))
                }
            }

            if stack.contains(.lTheanine) {
                let lTheanineDose = dose.amount * 2
                let peakOffset = 45 * 60
                let peakTime = time.addingTimeInterval(TimeInterval(peakOffset))

                points.append(TimelinePoint(
                    id: UUID(),
                    time: peakTime,
                    level: lTheanineDose,
                    compound: "L-Theanine",
                    isMainCompound: true
                ))

                for i in stride(from: 0, to: 16, by: 1) {
                    let t = time.addingTimeInterval(Double(i) * 1800)
                    guard t <= endTime else { break }
                    let hoursFromDose = Double(i) * 0.5
                    let level = lTheanineDose * pow(0.5, hoursFromDose / 4.0)
                    if level > 5 {
                        points.append(TimelinePoint(
                            id: UUID(),
                            time: t,
                            level: level,
                            compound: "L-Theanine",
                            isMainCompound: false
                        ))
                    }
                }
            }
        }

        return points.sorted { $0.time < $1.time }
    }

    private func calculateFocusWindow() -> FocusWindow? {
        guard !doses.isEmpty, let firstDose = doses.first, firstDose.time != nil else { return nil }

        let windowStart = firstDose.time!.addingTimeInterval(1800)
        let windowEnd = firstDose.time!.addingTimeInterval(3600 * 4)

        return FocusWindow(
            start: windowStart,
            end: windowEnd,
            peakLevel: firstDose.amount
        )
    }
}

struct TimelinePoint: Identifiable {
    let id: UUID
    let time: Date
    let level: Double
    let compound: String
    let isMainCompound: Bool
}
