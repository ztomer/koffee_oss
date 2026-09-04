import SwiftUI
import LiquidContainer

enum AppSection: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case stack = "Stack Builder"
    case history = "History"
    case notifications = "Notifications"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dashboard: return "chart.xyaxis.line"
        case .stack: return "pills.fill"
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
    @State private var selectedCompound: NootropicCompound?
    @State private var showInspector: Bool = true
    @State private var caffeineAtBedtime: Double = 0

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

    var activeStimulantLoad: Double {
        appState.todayCaffeineTotal
    }

    var activeDepressantLoad: Double {
        var load: Double = 0
        let todaySupplements = appState.supplementsForDate(Date())
        for log in todaySupplements {
            if let compound = NootropicCompound(rawValue: log.compoundName) {
                load += compound.optimalDoseMg * 0.2
            }
        }

        let pendingSupplements = appState.pendingNonCaffeineItemsToday()
        for item in pendingSupplements {
            if let compound = NootropicCompound(rawValue: item.compoundName) {
                load += compound.optimalDoseMg * 0.2
            }
        }

        return load
    }

    var bedtimeStatus: String {
        caffeineAtBedtime <= safeLimit * 0.5 ? "Sleep ready" : (caffeineAtBedtime <= safeLimit ? "Monitor" : "Too much")
    }

    var statusColor: Color {
        caffeineAtBedtime <= safeLimit * 0.5 ? .green : (caffeineAtBedtime <= safeLimit ? .yellow : .red)
    }

    var statusHeaderView: some View {
        HStack(spacing: 16) {
            Text("\(Int(currentCaffeine))mg")
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(.orange)

            Text("|")
                .foregroundStyle(.secondary)

            Text("\(Int(caffeineAtBedtime))mg @ bed")
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(statusColor)

            Text("|")
                .foregroundStyle(.secondary)

            HStack(spacing: 4) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.yellow)
                Text("\(Int(activeStimulantLoad))mg")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
            }

            HStack(spacing: 4) {
                Image(systemName: "moon.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.purple)
                Text("\(Int(activeDepressantLoad))mg")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
            }
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
            Section("Koffee") {
                ForEach([AppSection.dashboard, .stack, .history]) { section in
                    NavigationLink(value: section) {
                        Label(section.rawValue, systemImage: section.icon)
                    }
                }
            }

            Section("Tools") {
                NavigationLink(value: AppSection.notifications) {
                    Label("Notifications", systemImage: "bell")
                }
            }

            Section("Settings") {
                NavigationLink(value: AppSection.settings) {
                    Label("Preferences", systemImage: "gearshape")
                }
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 250)
    }

    private func addSupplement() {
        // Trigger supplement picker
    }

    private func addExercise() {
        // Trigger exercise picker
    }

    private func addWater() {
        try? appState.addHydration(amountMl: 250)
    }

    @ViewBuilder
    private var detailContent: some View {
        switch selectedSection {
        case .dashboard:
            DashboardView(appState: appState, columnVisibility: $columnVisibility, physicsEngine: sharedPhysicsEngine, window: nil)
        case .stack:
            StackView(appState: appState)
        case .history:
            HistoryView(appState: appState)
        case .notifications:
            NotificationsView(appState: appState)
        case .settings:
            BiometricDashboardView(appState: appState)
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
