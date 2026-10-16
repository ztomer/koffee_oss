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
                let now = DateHelper.now
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
}

enum EntrySource: Equatable {
    case loggedDose(String)       // from doses table - id
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
        "cup.and.saucer.fill"
    }
}

struct ProtocolTimelineView: View {
    @ObservedObject var appState: AppState

    @State private var selectedEntry: ProtocolTimelineEntry?

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
    }

    private var quickActionDock: some View {
        HStack(spacing: 12) {
            SidebarActionButton(
                icon: "cup.and.saucer.fill",
                label: NootropicCompound.caffeine.rawValue,
                color: .orange
            ) {
                // Single funnel: the add-dose sheet lives in MainSplitView and
                // listens for this notification, so logging works whether or
                // not the inspector is visible.
                NotificationCenter.default.post(name: .addDose, object: nil)
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

    private var timelineEntries: [ProtocolTimelineEntry] {
        var entries: [ProtocolTimelineEntry] = []

        debugLog("timelineEntries: todayPlan count = \(appState.pendingPlanItemsToday.count)")

        let today = DateHelper.startOfDay()

        // Use AppState date methods
        let todayDoses = appState.dosesForDate(today)
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

        // Plan items - only show pending (taken items are shown via history entries)
        for planItem in todayPlan {
            entries.append(ProtocolTimelineEntry(
                id: UUID(uuidString: planItem.id) ?? UUID(),
                scheduledTime: planItem.scheduledTime,
                type: .beverage,
                title: planItem.compoundName,
                subtitle: "\(Int(planItem.doseMg))mg",
                explanation: "Planned caffeine dose",
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
        let now = DateHelper.now
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
        let now = DateHelper.now
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
