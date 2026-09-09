import SwiftUI
import LiquidContainer

enum AppSection: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case history = "History"
    case notifications = "Notifications"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dashboard: return "chart.xyaxis.line"
        case .history: return "clock.fill"
        case .notifications: return "bell.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

struct WindowControlButton: View {
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
                .shadow(color: color.opacity(0.5), radius: 2)
        }
        .buttonStyle(.plain)
    }
}

@MainActor
class SharedPhysicsEngine: ObservableObject {
    let engine = LiquidPhysicsEngine()
}

struct MainSplitView: View {
    @ObservedObject var appState: AppState
    let sharedPhysicsEngine: SharedPhysicsEngine

    @State private var selectedSection: AppSection = .dashboard
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var showInspector: Bool = true
    @State private var showingBeveragePicker = false

    /// Bedtime projection comes from AppState (single source of truth).
    /// A local @State copy here silently froze the toolbar at 0mg.
    var caffeineAtBedtime: Double { appState.caffeineAtBedtime }

    init(appState: AppState, sharedPhysicsEngine: SharedPhysicsEngine) {
        self.appState = appState
        self.sharedPhysicsEngine = sharedPhysicsEngine
        debugLog("MainSplitView init - appState.profile: \(appState.profile != nil), doses: \(appState.doses.count)")
        debugLog("MainSplitView init - sharedPhysicsEngine.engine: \(sharedPhysicsEngine.engine), accelX: \(sharedPhysicsEngine.engine.containerAccelX)")
    }

    var safeLimit: Double {
        appState.safeCaffeineLimit
    }

    var currentCaffeine: Double {
        appState.todayCaffeineTotal
    }

    var pendingCaffeineTotal: Double {
        appState.pendingPlanItemsTodayByCompound("caffeine").reduce(0) { $0 + $1.doseMg }
    }

    var bedtimeStatus: String {
        caffeineAtBedtime <= safeLimit * 0.5 ? "Sleep ready" : (caffeineAtBedtime <= safeLimit ? "Monitor" : "Too much")
    }

    var statusColor: Color {
        caffeineAtBedtime <= safeLimit * 0.5 ? .green : (caffeineAtBedtime <= safeLimit ? .yellow : .red)
    }

    var statusHeaderView: some View {
        HStack(spacing: 6) {
            Text("\(Int(currentCaffeine))mg")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(.orange)

            Text("·")
                .foregroundStyle(.secondary)

            Text("Bedtime \(Int(caffeineAtBedtime))mg")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(statusColor)

            Text("·")
                .foregroundStyle(.secondary)

            Text("Planned \(Int(pendingCaffeineTotal))mg")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.blue)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial.opacity(0.8))
        .clipShape(.rect(cornerRadius: 20))
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebarContent
        } detail: {
            HStack(spacing: 0) {
                detailContent
                    .frame(maxWidth: .infinity)

                if showInspector {
                    ProtocolTimelineView(appState: appState)
                        .frame(width: 320)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                statusHeaderView
                    .frame(maxWidth: 600)
            }
            ToolbarItem(placement: .automatic) {
                Button(action: { showInspector.toggle() }, label: {
                    Image(systemName: "sidebar.right")
                })
            }
        }
        .navigationSplitViewStyle(.balanced)
        .onReceive(NotificationCenter.default.publisher(for: .addDose)) { _ in
            showingBeveragePicker = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .takeNext)) { _ in
            if let next = appState.pendingPlanItemsTodayByCompound("caffeine").sorted(by: { $0.scheduledTime < $1.scheduledTime }).first {
                try? appState.updatePlanItemStatus(id: next.id, status: .taken)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .skipNext)) { _ in
            if let next = appState.pendingPlanItemsTodayByCompound("caffeine").sorted(by: { $0.scheduledTime < $1.scheduledTime }).first {
                try? appState.updatePlanItemStatus(id: next.id, status: .skipped)
            }
        }
        .sheet(isPresented: $showingBeveragePicker) {
            AddBeverageSheet(appState: appState, onAdd: { beverage, time in
                try? appState.addDose(beverageId: beverage.id, timestamp: time, caffeineMg: Double(beverage.caffeineMg), beverageName: beverage.name)
                showingBeveragePicker = false
            }, onDismiss: { showingBeveragePicker = false })
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 1)
                .onChanged { value in
                    sharedPhysicsEngine.engine.containerAccelX += value.translation.width * 0.02
                }
                .onEnded { value in
                    sharedPhysicsEngine.engine.containerAccelX = value.velocity.width * 0.002
                }
        )
    }

    private var sidebarContent: some View {
        List(selection: $selectedSection) {
            ForEach(AppSection.allCases) { section in
                NavigationLink(value: section) {
                    Label(section.rawValue, systemImage: section.icon)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 250)
    }

    @ViewBuilder
    private var detailContent: some View {
        switch selectedSection {
        case .dashboard:
            DashboardView(appState: appState, columnVisibility: $columnVisibility, physicsEngine: sharedPhysicsEngine, window: nil)
        case .history:
            HistoryView(appState: appState)
        case .notifications:
            NotificationsView(appState: appState)
        case .settings:
            SettingsView(appState: appState)
        }
    }
}

struct QuickActionButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(label, systemImage: icon)
                .font(.system(size: 11))
        }
        .buttonStyle(.bordered)
    }
}
