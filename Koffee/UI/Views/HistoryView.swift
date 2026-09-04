import SwiftUI

struct DailyHistoryRecord: Identifiable {
    let id = UUID()
    let date: Date
    let totalCaffeineMg: Double
    let totalHydrationMl: Double
    let hydrationTargetMl: Double
    let hydrationLoggedMl: Double
    let bedtimeCaffeineMg: Double
    let sleepRiskLevel: String
    let stackCompounds: [String]
    let doseCount: Int
    let supplementCount: Int
    let exerciseCount: Int
    let doses: [DoseDetail]
    let hydrationEntries: [HydrationDetail]
    let exercises: [ExerciseDetail]
    let supplements: [SupplementDetail]
}

struct DoseDetail: Identifiable {
    let id = UUID()
    let time: Date
    let beverageName: String
    let caffeineMg: Double
}

struct HydrationDetail: Identifiable {
    let id = UUID()
    let time: Date
    let amountMl: Double
}

struct ExerciseDetail: Identifiable {
    let id = UUID()
    let time: Date
    let activityName: String
    let durationMinutes: Int?
}

struct SupplementDetail: Identifiable {
    let id = UUID()
    let time: Date
    let compoundName: String
    let doseMg: Double?
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
        for entry in appState.hydrationEntries {
            dates.insert(calendar.startOfDay(for: entry.timestamp))
        }
        for log in appState.supplementLogs {
            dates.insert(calendar.startOfDay(for: log.timestamp))
        }
        for log in appState.exerciseLogs {
            dates.insert(calendar.startOfDay(for: log.timestamp))
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
        let hydration = appState.hydrationInRange(start: start, end: end)
        let supplements = appState.supplementsInRange(start: start, end: end)
        let exercises = appState.exercisesInRange(start: start, end: end)

        let hasData = !doses.isEmpty || !hydration.isEmpty || !supplements.isEmpty || !exercises.isEmpty
        guard hasData else { return nil }

        let totalCaffeine = doses.reduce(0) { $0 + $1.caffeineMg }
        let totalHydration = hydration.reduce(0) { $0 + $1.amountMl }
        let stackCompounds = supplements.map { $0.compoundName }

        let doseDetails = doses.map { DoseDetail(time: $0.timestamp, beverageName: $0.beverageName ?? "Unknown", caffeineMg: $0.caffeineMg) }
        let hydrationDetails = hydration.map { HydrationDetail(time: $0.timestamp, amountMl: $0.amountMl) }
        let exerciseDetails = exercises.map { ExerciseDetail(time: $0.timestamp, activityName: $0.activityName, durationMinutes: $0.durationMinutes) }

        // Get optimal dose for each supplement from NootropicCompound
        let supplementDetails = supplements.map { supplement -> SupplementDetail in
            let compound = NootropicCompound(rawValue: supplement.compoundName)
            let doseMg = compound?.optimalDoseMg
            return SupplementDetail(time: supplement.timestamp, compoundName: supplement.compoundName, doseMg: doseMg)
        }

        return DailyHistoryRecord(
            date: start,
            totalCaffeineMg: totalCaffeine,
            totalHydrationMl: totalHydration,
            hydrationTargetMl: 2500,
            hydrationLoggedMl: totalHydration,
            bedtimeCaffeineMg: totalCaffeine * 0.3,
            sleepRiskLevel: totalCaffeine > 200 ? "high" : (totalCaffeine > 100 ? "medium" : "low"),
            stackCompounds: stackCompounds,
            doseCount: doses.count,
            supplementCount: supplements.count,
            exerciseCount: exercises.count,
            doses: doseDetails,
            hydrationEntries: hydrationDetails,
            exercises: exerciseDetails,
            supplements: supplementDetails
        )
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

                Spacer()

                Text(dayOfWeekString).font(.system(size: 14, weight: .semibold))

                Spacer()

                Button {
                    selectedDate = calendar.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
                    updateYearMonth()
                } label: {
                    Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold))
                }
                .buttonStyle(.plain)
                .disabled(calendar.isDateInToday(selectedDate))
            }

            HStack {
                Button {
                    selectedMonth = max(1, selectedMonth - 1)
                    if selectedMonth == 0 { selectedMonth = 12; selectedYear -= 1 }
                    if let newDate = calendar.date(from: DateComponents(year: selectedYear, month: selectedMonth, day: 1)) {
                        selectedDate = newDate
                    }
                } label: {
                    Image(systemName: "chevron.left").font(.system(size: 12))
                }
                .buttonStyle(.plain)

                Spacer()

                Text(monthYearString).font(.system(size: 16, weight: .bold))

                Spacer()

                Button {
                    selectedMonth = min(12, selectedMonth + 1)
                    if selectedMonth == 13 { selectedMonth = 1; selectedYear += 1 }
                    if let newDate = calendar.date(from: DateComponents(year: selectedYear, month: selectedMonth, day: 1)) {
                        selectedDate = newDate
                    }
                } label: {
                    Image(systemName: "chevron.right").font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .disabled(calendar.isDateInToday(selectedDate))
            }

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
                            Text("\(dayNumber)")
                                .font(.system(size: 12, weight: isSelected || isToday ? .bold : .regular))
                                .frame(width: 24, height: 24)
                                .background(isSelected ? Color.orange : (isToday ? Color.orange.opacity(0.3) : Color.clear))
                                .foregroundStyle(isSelected || isToday ? .white : .primary)
                                .clipShape(.circle)
                        }
                        .buttonStyle(.plain)
                        .overlay(Circle().stroke(hasRecord ? Color.green : Color.clear, lineWidth: 1))
                    }
                }
            }
        }
    }

    private var emptyStateForDate: some View {
        VStack(spacing: 16) {
            Image(systemName: "pills.fill")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("No data for \(dayString)")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
            if calendar.isDateInToday(selectedDate) {
                Text("Log your first supplement to start tracking")
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var dayOfWeekString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: selectedDate)
    }

    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: selectedDate)
    }

    private var dayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: selectedDate)
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

                if !record.supplements.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SUPPLEMENTS TAKEN").font(.system(size: 10, weight: .bold)).foregroundStyle(.secondary)
                        ForEach(record.supplements) { supplement in
                            HStack {
                                Text(formatTime(supplement.time))
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(.purple)
                                Text(supplement.compoundName)
                                    .font(.system(size: 11, weight: .medium))
                                Spacer()
                                if let dose = supplement.doseMg {
                                    Text("\(Int(dose))mg")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                if !record.hydrationEntries.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        Text("HYDRATION").font(.system(size: 10, weight: .bold)).foregroundStyle(.secondary)
                        ForEach(record.hydrationEntries) { entry in
                            HStack {
                                Text(formatTime(entry.time))
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(.blue)
                                Text("\(Int(entry.amountMl))ml")
                                    .font(.system(size: 11, weight: .medium))
                            }
                        }
                        HStack {
                            Text("Total: \(Int(record.hydrationLoggedMl))ml")
                                .font(.system(size: 11, weight: .semibold))
                            Text("of \(Int(record.hydrationTargetMl))ml target")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if !record.exercises.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        Text("EXERCISE").font(.system(size: 10, weight: .bold)).foregroundStyle(.secondary)
                        ForEach(record.exercises) { exercise in
                            HStack {
                                Text(formatTime(exercise.time))
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(.green)
                                Text(exercise.activityName)
                                    .font(.system(size: 11, weight: .medium))
                                if let duration = exercise.durationMinutes {
                                    Spacer()
                                    Text("\(duration)min")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    Text("SLEEP IMPACT").font(.system(size: 10, weight: .bold)).foregroundStyle(.secondary)
                    let bedtimeRisk = record.bedtimeCaffeineMg > 100 ? "High" : (record.bedtimeCaffeineMg > 50 ? "Medium" : "Low")
                    let riskColor: Color = bedtimeRisk == "High" ? .red : (bedtimeRisk == "Medium" ? .yellow : .green)
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
