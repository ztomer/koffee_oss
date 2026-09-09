import SwiftUI

struct DailyHistoryRecord: Identifiable {
    let id = UUID()
    let date: Date
    let totalCaffeineMg: Double
    let bedtimeCaffeineMg: Double
    let sleepRiskLevel: String
    let doseCount: Int
    let doses: [DoseDetail]
}

struct DoseDetail: Identifiable {
    let id = UUID()
    let time: Date
    let beverageName: String
    let caffeineMg: Double
}

struct HistoryView: View {
    @ObservedObject var appState: AppState
    @State private var selectedDate: Date = Date()
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var selectedMonth: Int = Calendar.current.component(.month, from: Date())

    private var calendar: Calendar { Calendar.current }

    private var historyRecordForSelectedDate: DailyHistoryRecord? {
        computeDailyRecord(for: selectedDate)
    }

    private var datesWithData: Set<Date> {
        var dates: Set<Date> = []
        let calendar = Calendar.current

        for dose in appState.doses {
            dates.insert(calendar.startOfDay(for: dose.timestamp))
        }

        return dates
    }

    var body: some View {
        VStack(spacing: 16) {
            dateNavigationHeader

            if let record = historyRecordForSelectedDate {
                HistoryDetailCard(record: record)
            } else {
                emptyStateForDate
            }

            Spacer()
        }
        .padding(20)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func computeDailyRecord(for date: Date) -> DailyHistoryRecord? {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!

        let doses = appState.dosesInRange(start: start, end: end)

        guard !doses.isEmpty else { return nil }

        let totalCaffeine = doses.reduce(0) { $0 + $1.caffeineMg }

        let doseDetails = doses.map { DoseDetail(time: $0.timestamp, beverageName: $0.beverageName ?? "Unknown", caffeineMg: $0.caffeineMg) }

        // Same bedtime funnel as toolbar + dashboard: project the day's
        // doses against that day's sleep wall-time with the user's metabolism.
        // Risk bands mirror the dashboard oracle (fractions of safeLimit).
        let profile = appState.profile
        let metabolism = MetabolismRate(swiftDataValue: profile?.metabolismRate ?? "") ?? .medium
        let safeLimit = appState.safeCaffeineLimit
        let wakeWallTime = profile?.wakeTime ?? calendar.date(bySettingHour: 7, minute: 0, second: 0, of: start)!
        let sleepWallTime = profile?.sleepTime ?? calendar.date(bySettingHour: 23, minute: 0, second: 0, of: start)!
        let wakeTime = transposedWallTime(from: wakeWallTime, onto: start, calendar: calendar)
        let sleepTime = transposedWallTime(from: sleepWallTime, onto: start, calendar: calendar)
        let bedtimeMg = projectBedtimeCaffeine(
            doses: doses.map { ($0.timestamp, $0.caffeineMg) },
            wakeTime: wakeTime,
            sleepTime: sleepTime,
            metabolism: metabolism
        )

        return DailyHistoryRecord(
            date: start,
            totalCaffeineMg: totalCaffeine,
            bedtimeCaffeineMg: bedtimeMg,
            sleepRiskLevel: bedtimeMg > safeLimit ? "high" : (bedtimeMg > safeLimit * 0.5 ? "medium" : "low"),
            doseCount: doses.count,
            doses: doseDetails
        )
    }

    /// Projects a wall-clock time (hour/minute from the profile) onto a date.
    private func transposedWallTime(from wallTime: Date, onto date: Date, calendar: Calendar) -> Date {
        let comps = calendar.dateComponents([.hour, .minute, .second], from: wallTime)
        return calendar.date(bySettingHour: comps.hour ?? 0, minute: comps.minute ?? 0, second: comps.second ?? 0, of: date) ?? date
    }

    private var dateNavigationHeader: some View {
        VStack(spacing: 12) {
            HStack {
                Button {
                    selectedDate = calendar.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
                    updateYearMonth()
                } label: {
                    Image(systemName: "chevron.left").font(.system(size: 14, weight: .semibold))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Previous day")

                Spacer()

                Text(dayString).font(.system(size: 14, weight: .semibold))

                Spacer()

                Button {
                    selectedDate = calendar.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
                    updateYearMonth()
                } label: {
                    Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold))
                }
                .buttonStyle(.plain)
                .disabled(calendar.isDateInToday(selectedDate))
                .accessibilityLabel("Next day")
            }

            Menu {
                ForEach(1...12, id: \.self) { month in
                    Button(monthName(month)) {
                        selectedMonth = month
                        if let newDate = calendar.date(from: DateComponents(year: selectedYear, month: month, day: 1)) {
                            selectedDate = newDate
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(monthYearString).font(.system(size: 16, weight: .bold))
                    Image(systemName: "chevron.down").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Jump to month")

            monthGrid
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(.rect(cornerRadius: 12))
    }

    private var monthGrid: some View {
        let daysInMonth = calendar.range(of: .day, in: .month, for: selectedDate)?.count ?? 30
        let firstDayOfMonth = calendar.date(from: DateComponents(year: selectedYear, month: selectedMonth, day: 1)) ?? selectedDate
        let weekdayOffset = calendar.component(.weekday, from: firstDayOfMonth) - 1

        return VStack(spacing: 4) {
            HStack {
                ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { day in
                    Text(day).font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 4) {
                ForEach(0..<42, id: \.self) { index in
                    let dayNumber = index - weekdayOffset + 1
                    if dayNumber < 1 || dayNumber > daysInMonth {
                        Text("").frame(height: 24)
                    } else {
                        let date = calendar.date(from: DateComponents(year: selectedYear, month: selectedMonth, day: dayNumber)) ?? selectedDate
                        let hasRecord = datesWithData.contains(date)
                        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
                        let isToday = calendar.isDateInToday(date)

                        Button {
                            selectedDate = date
                        } label: {
                            VStack(spacing: 1) {
                                Text("\(dayNumber)")
                                    .font(.system(size: 12, weight: isSelected || isToday || hasRecord ? .bold : .regular))
                                    .frame(width: 24, height: 24)
                                    .background(isSelected ? Color.orange : (isToday ? Color.orange.opacity(0.3) : Color.clear))
                                    .foregroundStyle(isSelected || isToday ? .white : .primary)
                                    .clipShape(.circle)
                                Circle()
                                    .fill(hasRecord ? (isSelected ? Color.white : Color.green) : Color.clear)
                                    .frame(width: 4, height: 4)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var emptyStateForDate: some View {
        VStack(spacing: 16) {
            Image(systemName: "cup.and.saucer.fill")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("No data for \(dayString)")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
            if calendar.isDateInToday(selectedDate) {
                Text("Log your first coffee to start tracking")
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: selectedDate)
    }

    private var dayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d, yyyy"
        return formatter.string(from: selectedDate)
    }

    private func monthName(_ month: Int) -> String {
        let formatter = DateFormatter()
        return formatter.monthSymbols[month - 1]
    }

    private func updateYearMonth() {
        selectedYear = calendar.component(.year, from: selectedDate)
        selectedMonth = calendar.component(.month, from: selectedDate)
    }
}

struct HistoryDetailCard: View {
    let record: DailyHistoryRecord

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(formatDate(record.date))
                        .font(.system(size: 16, weight: .semibold))
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("\(Int(record.totalCaffeineMg))mg")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.orange)
                        Text("total caffeine").font(.system(size: 9)).foregroundStyle(.secondary)
                    }
                }

                if !record.doses.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        Text("DOSES").font(.system(size: 10, weight: .bold)).foregroundStyle(.secondary)
                        ForEach(record.doses) { dose in
                            HStack {
                                Text(formatTime(dose.time))
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(.orange)
                                Text(dose.beverageName)
                                    .font(.system(size: 11, weight: .medium))
                                Spacer()
                                Text("\(Int(dose.caffeineMg))mg")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    Text("SLEEP IMPACT").font(.system(size: 10, weight: .bold)).foregroundStyle(.secondary)
                    let bedtimeRisk = record.sleepRiskLevel.capitalized
                    let riskColor: Color = record.sleepRiskLevel == "high" ? .red : (record.sleepRiskLevel == "medium" ? .yellow : .green)
                    HStack {
                        Image(systemName: "moon.zzz").foregroundStyle(riskColor)
                        Text("\(Int(record.bedtimeCaffeineMg))mg at bedtime - \(bedtimeRisk) risk").font(.system(size: 11)).foregroundStyle(riskColor)
                    }
                }
            }
            .padding(16)
        }
        .background(.ultraThinMaterial)
        .clipShape(.rect(cornerRadius: 12))
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d, yyyy"
        return formatter.string(from: date)
    }
}
