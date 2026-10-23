import SwiftUI
import AppKit
import Combine

@MainActor
class MenuBarManager: ObservableObject {
    private var _statusItem: NSStatusItem?
    var popover: NSPopover?

    @Published var currentLevel: Double = 0
    @Published var riskLevel: RiskLevel = .low
    weak var appState: AppState?
    private var cancellables = Set<AnyCancellable>()

    var statusItem: NSStatusItem? {
        return _statusItem
    }

    func setup(appState: AppState? = nil) {
        self.appState = appState
        _statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            updateStatusIcon()
            button.action = #selector(togglePopover)
            button.target = self
        }

        popover = NSPopover()
        popover?.contentSize = NSSize(width: 280, height: 190)
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(rootView: MenuBarPopoverView(controller: self))

        if appState != nil {
            bindAppState()
        }
    }

    func bind(appState: AppState) {
        self.appState = appState
        bindAppState()
    }

    private func bindAppState() {
        guard let appState = appState else { return }
        cancellables.removeAll()

        appState.$currentCaffeineLevel
            .combineLatest(appState.$caffeineAtBedtime)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] level, bedtime in
                guard let self = self else { return }
                let limit = self.appState?.safeCaffeineLimit ?? CaffeineConstants.defaultBedtimeMg
                let risk: RiskLevel
                if bedtime > limit * 1.5 {
                    risk = .critical
                } else if bedtime > limit {
                    risk = .high
                } else if bedtime > limit * 0.5 {
                    risk = .medium
                } else {
                    risk = .low
                }
                self.updateStatus(level: level, risk: risk)
            }
            .store(in: &cancellables)
    }

    func updateStatus(level: Double, risk: RiskLevel) {
        self.currentLevel = level
        self.riskLevel = risk
        updateStatusIcon()
    }

    func logQuickDose() {
        guard let state = appState else { return }
        let beverage: (id: String?, name: String, mg: Double)
        if let usualId = state.usualBeverageId, let usual = state.findBeverage(byId: usualId) {
            beverage = (usual.id, usual.name, Double(usual.caffeineMg))
        } else if let first = state.beverages.first {
            beverage = (first.id, first.name, Double(first.caffeineMg))
        } else {
            beverage = (nil, "Coffee", 95.0)
        }

        do {
            try state.addDose(
                beverageId: beverage.id,
                timestamp: DateHelper.now,
                caffeineMg: beverage.mg,
                beverageName: beverage.name
            )
            popover?.performClose(nil)
        } catch {
            debugLog("Quick log failed: \(error)")
        }
    }

    func logDose(beverage: BeverageModel) {
        guard let state = appState else { return }
        do {
            try state.addDose(
                beverageId: beverage.id,
                timestamp: DateHelper.now,
                caffeineMg: Double(beverage.caffeineMg),
                beverageName: beverage.name
            )
            popover?.performClose(nil)
        } catch {
            debugLog("Log beverage dose failed: \(error)")
        }
    }

    func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0 is KoffeeWindow || $0.canBecomeMain }) {
            window.makeKeyAndOrderFront(nil)
        }
        popover?.performClose(nil)
    }

    private func updateStatusIcon() {
        guard let button = statusItem?.button else { return }

        let color: NSColor
        let symbol: String

        switch riskLevel {
        case .low:
            color = .systemGreen
            symbol = "brain.fill"
        case .medium:
            color = .systemYellow
            symbol = "brain.fill"
        case .high:
            color = .systemOrange
            symbol = "brain.fill"
        case .critical:
            color = .systemRed
            symbol = "brain.fill"
        }

        let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        if let image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?.withSymbolConfiguration(config) {
            if let coloredImage = image.copy() as? NSImage {
                coloredImage.isTemplate = false
                button.image = coloredImage
                button.contentTintColor = color
            }
        }

        button.title = " \(Int(currentLevel))mg"
    }

    @objc private func togglePopover() {
        guard let popover = popover else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else if let button = statusItem?.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
}

struct MenuBarPopoverView: View {
    @ObservedObject var controller: MenuBarManager

    private var usualBeverage: BeverageModel? {
        if let id = controller.appState?.usualBeverageId,
           let bev = controller.appState?.findBeverage(byId: id) {
            return bev
        }
        return controller.appState?.beverages.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Koffee Status")
                    .font(.system(size: 14, weight: .bold))
                Spacer()
            }

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Level")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Text("\(Int(controller.currentLevel))mg")
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundStyle(.orange)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Risk")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    riskBadge
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("Quick Actions")
                    .font(.system(size: 12, weight: .semibold))

                HStack(spacing: 8) {
                    if let beverage = usualBeverage {
                        Button("Log \(beverage.name) (\(Int(beverage.caffeineMg))mg)") {
                            controller.logQuickDose()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                    } else {
                        Button("Log Coffee (95mg)") {
                            controller.logQuickDose()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                    }

                    Button("Open Koffee") {
                        controller.openMainWindow()
                    }
                    .buttonStyle(.bordered)
                }

                if let beverages = controller.appState?.beverages, beverages.count > 1 {
                    Menu("Other Beverage…") {
                        ForEach(beverages) { bev in
                            Button("\(bev.name) (\(Int(bev.caffeineMg))mg)") {
                                controller.logDose(beverage: bev)
                            }
                        }
                    }
                    .menuStyle(.borderlessButton)
                    .font(.system(size: 11))
                }
            }

            Spacer()
        }
        .padding()
        .frame(width: 280, height: 190)
    }

    private var riskBadge: some View {
        let color: Color
        switch controller.riskLevel {
        case .low: color = .green
        case .medium: color = .yellow
        case .high: color = .orange
        case .critical: color = .red
        }

        return HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(controller.riskLevel.rawValue)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(color)
        }
    }
}
