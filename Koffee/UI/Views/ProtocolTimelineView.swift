import SwiftUI
import GRDB

struct TimeBlock: Identifiable {
    let id = UUID()
    let time: Date
    var entries: [ProtocolTimelineEntry]
}

struct TimelineGapView: View {
    let prevTime: Date?
    let nextTime: Date?
    let isActiveSegment: Bool

    var body: some View {
        if isActiveSegment, let prev = prevTime, let next = nextTime {
            GeometryReader { geometry in
                let now = Date()
                let totalSeconds = next.timeIntervalSince(prev)
                let elapsedSeconds = now.timeIntervalSince(prev)
                let progress = max(0, min(1, elapsedSeconds / totalSeconds))
                let xPos = progress * geometry.size.width

                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.red.opacity(0.15))
                        .frame(height: 2)
                        .frame(maxWidth: .infinity)

                    Rectangle()
                        .fill(Color.red)
                        .frame(width: 2, height: 2)
                        .offset(x: xPos - 1)
                }
            }
            .frame(height: 24)
        } else if isActiveSegment && prevTime != nil && nextTime == nil {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.red.opacity(0.15))
                        .frame(height: 2)
                        .frame(maxWidth: .infinity)

                    Rectangle()
                        .fill(Color.red)
                        .frame(width: 2, height: 2)
                        .offset(x: geometry.size.width - 1)
                }
            }
            .frame(height: 24)
        } else {
            Color.clear
                .frame(height: 24)
        }
    }
}

enum EntryType {
    case beverage
    case supplement
    case physical
    case hydration
}

enum EntrySource: Equatable {
    case loggedDose(String)       // from doses table - id
    case loggedSupplement(String)  // from supplement_logs table - id
    case loggedHydration(String)  // from hydration_entries table - id
    case loggedExercise(String)    // from exercise_logs table - id
    case planItem(String)          // from daily_plan_items table - id
}

struct ProtocolTimelineEntry: Identifiable {
    let id: UUID
    let scheduledTime: Date
    let type: EntryType
    let title: String
    let subtitle: String
    let explanation: String
    let isSuggestion: Bool
    let isLogged: Bool
    let source: EntrySource  // Track where this entry came from

    var icon: String {
        switch type {
        case .beverage: return "cup.and.saucer.fill"
        case .supplement: return "pills.fill"
        case .physical: return "figure.walk"
        case .hydration: return "drop.fill"
        }
    }
}

struct ProtocolTimelineView: View {
    @ObservedObject var appState: AppState

    @State private var selectedEntry: ProtocolTimelineEntry?
    @State private var showingBeveragePicker = false
    @State private var showingSupplementPicker = false
    @State private var showingActivityPicker = false

    private var completedPlanItemIDs: Set<String> {
        appState.takenPlanItemIds
    }

    private var skippedPlanItemIDs: Set<String> {
        appState.skippedPlanItemIds
    }

    private func isPlanItemCompleted(_ entry: ProtocolTimelineEntry) -> Bool {
        if case .planItem(let id) = entry.source {
            return completedPlanItemIDs.contains(id)
        }
        return false
    }

    private func isPlanItemSkipped(_ entry: ProtocolTimelineEntry) -> Bool {
        if case .planItem(let id) = entry.source {
            return skippedPlanItemIDs.contains(id)
        }
        return false
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(timelineEntries) { entry in
                        TimelineEntryView(
                            entry: entry,
                            isCompleted: isPlanItemCompleted(entry),
                            isSkipped: isPlanItemSkipped(entry),
                            isSelected: selectedEntry?.id == entry.id,
                            onTap: { toggleSelection(entry) },
                            onApprove: { approveEntry(entry) },
                            onSkip: { skipEntry(entry) },
                            onDisapprove: { disapproveEntry(entry) },
                            onCancel: { cancelEntry(entry) }
                        )
                    }
                }
                .padding(.vertical, 10)
            }
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            quickActionDock
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .onReceive(NotificationCenter.default.publisher(for: .addDose)) { _ in
            showingBeveragePicker = true
        }
        .sheet(isPresented: $showingBeveragePicker) {
            AddBeverageSheet(appState: appState, onAdd: { beverage, time in
                try? appState.addDose(beverageId: beverage.id, timestamp: time, caffeineMg: Double(beverage.caffeineMg), beverageName: beverage.name)
                showingBeveragePicker = false
            }, onDismiss: { showingBeveragePicker = false })
        }
        .sheet(isPresented: $showingSupplementPicker) {
            AddSupplementSheet(appState: appState, onAdd: { compoundName in
                try? appState.addSupplement(compoundName: compoundName)
                showingSupplementPicker = false
            }, onDismiss: { showingSupplementPicker = false })
        }
        .sheet(isPresented: $showingActivityPicker) {
            AddExerciseSheet(appState: appState, onAdd: { activityName, duration in
                try? appState.addExercise(activityName: activityName, durationMinutes: duration)
                showingActivityPicker = false
            }, onDismiss: { showingActivityPicker = false })
        }
    }

    private var quickActionDock: some View {
        HStack(spacing: 12) {
            SidebarActionButton(
                icon: "cup.and.saucer.fill",
                label: NootropicCompound.caffeine.rawValue,
                color: .orange
            ) {
                showingBeveragePicker = true
            }

            SidebarActionButton(
                icon: "pills.fill",
                label: "Supplement",
                color: .green
            ) {
                showingSupplementPicker = true
            }

            SidebarActionButton(
                icon: "figure.run",
                label: "Exercise",
                color: .cyan
            ) {
                showingActivityPicker = true
            }

            SidebarActionButton(
                icon: "drop.fill",
                label: "Water",
                color: .blue
            ) {
                logWater()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private func timeBlockView(index: Int, block: TimeBlock) -> some View {
        ForEach(block.entries) { entry in
            TimelineEntryView(
                entry: entry,
                isCompleted: isPlanItemCompleted(entry),
                isSkipped: isPlanItemSkipped(entry),
                isSelected: selectedEntry?.id == entry.id,
                onTap: { toggleSelection(entry) },
                onApprove: { approveEntry(entry) },
                onSkip: { skipEntry(entry) },
                onDisapprove: { disapproveEntry(entry) },
                onCancel: { cancelEntry(entry) }
            )
        }

        let isLastBlock = index == groupedTimeBlocks.count - 1
        let nextBlockTime = isLastBlock ? nil : groupedTimeBlocks.first(where: { $0.time > block.time })?.time
        let isActive = isTimeInActiveSegment(blockTime: block.time, nextBlockTime: nextBlockTime)

        TimelineGapView(
            prevTime: block.time,
            nextTime: nextBlockTime,
            isActiveSegment: isActive
        )
    }

    private func logWater() {
        try? appState.addHydration(amountMl: 250.0)
    }

    private var timelineEntries: [ProtocolTimelineEntry] {
        var entries: [ProtocolTimelineEntry] = []

        debugLog("timelineEntries: todayPlan count = \(appState.pendingPlanItemsToday.count)")

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Use AppState date methods
        let todayDoses = appState.dosesForDate(today)
        let todayHydration = appState.hydrationForDate(today)
        let todaySupplements = appState.supplementsForDate(today)
        let todayExercise = appState.exercisesForDate(today)
        let todayPlan = appState.pendingPlanItemsToday

        // Actual logged items - only from today
        for dose in todayDoses {
            // Get the planned time from the plan item (if it exists)
            let plannedTime: String? = {
                if let planItem = appState.findPlanItem(byId: dose.id) {
                    return formatTime(planItem.scheduledTime)
                }
                return nil
            }()

            let subtitle: String
            if let planned = plannedTime {
                subtitle = "\(Int(dose.caffeineMg))mg (planned \(planned))"
            } else {
                subtitle = "\(Int(dose.caffeineMg))mg caffeine"
            }

            entries.append(ProtocolTimelineEntry(
                id: UUID(uuidString: dose.id) ?? UUID(),
                scheduledTime: dose.timestamp,
                type: .beverage,
                title: dose.beverageName ?? "Unknown",
                subtitle: subtitle,
                explanation: "Logged \(dose.beverageName ?? "beverage") intake",
                isSuggestion: false,
                isLogged: true,
                source: .loggedDose(dose.id)
            ))
        }

        for entry in todayHydration {
            entries.append(ProtocolTimelineEntry(
                id: UUID(uuidString: entry.id) ?? UUID(),
                scheduledTime: entry.timestamp,
                type: .hydration,
                title: "Water",
                subtitle: "\(Int(entry.amountMl))ml",
                explanation: "Logged water intake",
                isSuggestion: false,
                isLogged: true,
                source: .loggedHydration(entry.id)
            ))
        }

        for log in todaySupplements {
            // Get the planned time from the plan item (if it exists)
            let plannedTime: String? = {
                if let planItem = appState.findPlanItem(byId: log.id) {
                    return formatTime(planItem.scheduledTime)
                }
                return nil
            }()

            // Get dose amount for this compound
            let compound = NootropicCompound(rawValue: log.compoundName)
            let doseMg = compound?.optimalDoseMg ?? 0

            let subtitle: String
            if let planned = plannedTime {
                subtitle = "\(Int(doseMg))mg (planned \(planned))"
            } else if doseMg > 0 {
                // For opportunistic supplements (not from plan), show dose + time
                subtitle = "\(Int(doseMg))mg at \(formatTime(log.timestamp))"
            } else {
                // For custom compounds without dose
                subtitle = formatTime(log.timestamp)
            }

            entries.append(ProtocolTimelineEntry(
                id: UUID(uuidString: log.id) ?? UUID(),
                scheduledTime: log.timestamp,
                type: .supplement,
                title: log.compoundName,
                subtitle: subtitle,
                explanation: "Logged \(log.compoundName) supplement",
                isSuggestion: false,
                isLogged: true,
                source: .loggedSupplement(log.id)
            ))
        }

        for log in todayExercise {
            let duration = log.durationMinutes.map { "\($0)min" } ?? ""
            entries.append(ProtocolTimelineEntry(
                id: UUID(uuidString: log.id) ?? UUID(),
                scheduledTime: log.timestamp,
                type: .physical,
                title: log.activityName,
                subtitle: duration,
                explanation: "Logged \(log.activityName)",
                isSuggestion: false,
                isLogged: true,
                source: .loggedExercise(log.id)
            ))
        }

        // Plan items - only show pending (taken items are shown via history entries)
        for planItem in todayPlan {
            let type: EntryType = planItem.compoundUuid == "caffeine" ? .beverage : .supplement

            // Use the actual dose stored in the plan item
            let subtitle: String
            if planItem.doseMg > 0 {
                subtitle = "\(Int(planItem.doseMg))mg"
            } else if planItem.compoundUuid == "caffeine" {
                subtitle = "\(Int(planItem.doseMg))mg"
            } else {
                subtitle = planItem.compoundName
            }

            entries.append(ProtocolTimelineEntry(
                id: UUID(uuidString: planItem.id) ?? UUID(),
                scheduledTime: planItem.scheduledTime,
                type: type,
                title: planItem.compoundName,
                subtitle: subtitle,
                explanation: planItem.compoundUuid == "caffeine" ? "Planned caffeine dose" : "Planned \(planItem.compoundName)",
                isSuggestion: true,
                isLogged: false,
                source: .planItem(planItem.id)
            ))
        }

        return entries.sorted { $0.scheduledTime < $1.scheduledTime }
    }

    private var groupedTimeBlocks: [TimeBlock] {
        let entries = timelineEntries

        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)

        var grouped: [Date: [ProtocolTimelineEntry]] = [:]

        for entry in entries {
            let hour = calendar.component(.hour, from: entry.scheduledTime)
            let minute = calendar.component(.minute, from: entry.scheduledTime)
            let timeOffset = Double(hour * 3600 + minute * 60)
            let roundedTime = todayStart.addingTimeInterval(timeOffset)

            if grouped[roundedTime] == nil {
                grouped[roundedTime] = []
            }
            grouped[roundedTime]?.append(entry)
        }

        return grouped.map { TimeBlock(time: $0.key, entries: $0.value) }
            .sorted { $0.time < $1.time }
    }

    private func approveEntry(_ entry: ProtocolTimelineEntry) {
        // Only plan items can be approved
        if case .planItem(let id) = entry.source {
            try? appState.updatePlanItemStatus(id: id, status: .taken)
        }
    }

    private func skipEntry(_ entry: ProtocolTimelineEntry) {
        // Only plan items can be skipped
        if case .planItem(let id) = entry.source {
            try? appState.updatePlanItemStatus(id: id, status: .skipped)
        }
    }

    private func disapproveEntry(_ entry: ProtocolTimelineEntry) {
        // Only plan items can be disapproved
        if case .planItem(let id) = entry.source {
            try? appState.updatePlanItemStatus(id: id, status: .pending)
        }
    }

    private func cancelEntry(_ entry: ProtocolTimelineEntry) {
        // Use source enum to determine how to handle removal
        switch entry.source {
        case .loggedDose(let id):
            if let dose = appState.findDose(byId: id) {
                try? appState.removeDose(dose)
            }
        case .loggedHydration(let id):
            if let hydEntry = appState.findHydration(byId: id) {
                try? appState.removeHydration(hydEntry)
            }
        case .loggedSupplement(let id):
            if let log = appState.findSupplement(byId: id) {
                try? appState.removeSupplement(log)
            }
        case .loggedExercise(let id):
            if let log = appState.findExercise(byId: id) {
                try? appState.removeExercise(log)
            }
        case .planItem(let id):
            // Skip plan item: mark as "skipped" in DB + delete history if was approved
            try? appState.skipPlanItem(id: id)
        }
    }

    private func toggleSelection(_ entry: ProtocolTimelineEntry) {
        if selectedEntry?.id == entry.id {
            selectedEntry = nil
        } else {
            selectedEntry = entry
        }
    }

    private func isTimeInActiveSegment(blockTime: Date, nextBlockTime: Date?) -> Bool {
        let now = Date()
        if let next = nextBlockTime {
            return blockTime <= now && now < next
        }
        return blockTime <= now
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
