import SwiftUI
import AppKit

@MainActor
class MenuBarManager: ObservableObject {
    private var _statusItem: NSStatusItem?
    private var popover: NSPopover?

    @Published var currentLevel: Double = 0
    @Published var riskLevel: RiskLevel = .low

    var statusItem: NSStatusItem? {
        return _statusItem
    }

    func setup() {
        _statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            updateStatusIcon()
            button.action = #selector(togglePopover)
            button.target = self
        }

        popover = NSPopover()
        popover?.contentSize = NSSize(width: 300, height: 200)
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(rootView: MenuBarPopoverView(controller: self))
    }

    func updateStatus(level: Double, risk: RiskLevel) {
        self.currentLevel = level
        self.riskLevel = risk
        updateStatusIcon()
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
            // NSImage.copy() is typed Any; a copied NSImage always downcasts.
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
                    Button("Log Coffee") {}
                        .buttonStyle(.bordered)

                    Button("View Timeline") {}
                        .buttonStyle(.bordered)
                }
            }

            Spacer()
        }
        .padding()
        .frame(width: 280, height: 180)
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
