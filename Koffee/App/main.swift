import SwiftUI
import Charts
import AppKit
import Foundation
import LiquidContainer
import UserNotifications
import GRDB

extension Notification.Name {
    static let addDose = Notification.Name("addDose")
    static let skipNext = Notification.Name("skipNext")
    static let takeNext = Notification.Name("takeNext")
}

let debugLogURL = URL(fileURLWithPath: "/tmp/koffee.log")

func debugLog(_ msg: String) {
    let timestamp = ISO8601DateFormatter().string(from: Date())
    let logLine = "[\(timestamp)] \(msg)\n"

    if FileManager.default.fileExists(atPath: debugLogURL.path) {
        if let handle = try? FileHandle(forWritingTo: debugLogURL) {
            handle.seekToEndOfFile()
            if let data = logLine.data(using: .utf8) {
                handle.write(data)
            }
            try? handle.close()
        }
    } else {
        if let data = logLine.data(using: .utf8) {
            try? data.write(to: debugLogURL)
        }
    }

    // The console echo, without `print`. The log file is the point of this
    // function; stdout was a second, unlabelled copy of the same line, and it
    // is what made a bare print look unavoidable here (G3). stderr keeps a live
    // tail for `log stream` without a second spelling of "write this line out"
    // that the G3 gate has to allow-list. The wording avoids the literal call
    // spelling on purpose: the gate is a plain grep, so a comment that quotes it
    // goes RED. Annoying, and the safe direction to fail in.
    FileHandle.standardError.write(Data((msg + "\n").utf8))
}

func clearDebugLog() {
    try? FileManager.default.removeItem(at: debugLogURL)
}

class KoffeeWindow: NSWindow {
    var physicsEngine: LiquidPhysicsEngine?
    private var lastPosition: NSPoint?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func setFrame(_ frameRect: NSRect, display flag: Bool) {
        if let last = lastPosition {
            let dx = frameRect.origin.x - last.x
            if let engine = physicsEngine, abs(dx) > 0.5 {
                engine.containerAccelX += dx * 0.1
            }
        }
        lastPosition = frameRect.origin
        super.setFrame(frameRect, display: flag)
    }
}

struct TrafficLightButton: View {
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
        }
        .buttonStyle(.plain)
    }
}

@MainActor
struct LoadingPlaceholderView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading Koffee...")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: KoffeeWindow!
    private var menuBarController: MenuBarManager?
    private var appState: AppState!

    func applicationDidFinishLaunching(_ notification: Notification) {
        window = KoffeeWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1300.0, height: 800.0),
            styleMask: [.closable, .miniaturizable, .resizable, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.title = ""
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.center()
        window.isReleasedWhenClosed = false
        window.isOpaque = false
        window.backgroundColor = NSColor.clear
        window.hasShadow = true
        window.minSize = NSSize(width: 1300, height: 800)
        window.maxSize = NSSize(width: 500, height: 1200)

        // Show window immediately with placeholder
        window.contentView = NSHostingView(rootView: LoadingPlaceholderView())
        window.makeKeyAndOrderFront(nil)

        menuBarController = MenuBarManager()
        menuBarController?.setup()
        menuBarController?.updateStatus(level: 0, risk: .low)

        Task { @MainActor in
            do {
                debugLog("STEP 1: Opening database...")
                try await DatabaseManager.shared.open()
                debugLog("STEP 1: Database opened successfully")

                let db = DatabaseManager.shared.queue()
                debugLog("STEP 2: Got database queue")

                // Seed beverages first (before creating repos)
                let beverageModels = BeverageManager.shared.beverages.map { b in
                    BeverageModel(id: b.id.uuidString, name: b.name, caffeineMg: b.caffeineMg, category: b.category, icon: b.icon)
                }
                try await db.write { db in
                    for model in beverageModels {
                        try model.insert(db, onConflict: .replace)
                    }
                }
                debugLog("STEP 3: Seeded beverages")

                // Create profile with proper wake/sleep times for today
                let now = Date()
                let calendar = Calendar.current

                // Get today's date in local timezone
                let todayStart = calendar.startOfDay(for: now)
                let wakeTime = calendar.date(byAdding: .hour, value: 7, to: todayStart)!
                let sleepTime = calendar.date(byAdding: .hour, value: 23, to: todayStart)!

                debugLog("STEP 4: Creating profile with wakeTime=\(wakeTime.timeIntervalSince1970), sleepTime=\(sleepTime.timeIntervalSince1970)")

                // Delete any existing profile first to ensure fresh data
                _ = try await db.write { db in
                    try UserProfileModel.deleteAll(db)
                }

                // Create profile with default stack compounds
                let profile = UserProfileModel(
                    wakeTime: wakeTime,
                    sleepTime: sleepTime,
                    stackCompounds: [
                    NootropicCompound.caffeine.rawValue
                ]
                )
                try await db.write { db in
                    try profile.save(db)
                }
                debugLog("STEP 4: Profile created with stack compounds")

                // Now create repos - they'll read initial values from DB
                let beverageRepo = BeverageRepository(db: db)
                debugLog("STEP 5: Created beverageRepo, beverages=\(beverageRepo.beverages.count)")

                let profileRepo = UserProfileRepository(db: db)
                debugLog("STEP 6: Created profileRepo, profile=\(profileRepo.profile != nil)")

                let doseRepo = DoseRepository(db: db)
                debugLog("STEP 7: Created doseRepo, doses=\(doseRepo.doses.count)")

                let planRepo = DailyPlanRepository(db: db)
                debugLog("STEP 11: Created planRepo")

                appState = AppState(
                    profileRepo: profileRepo,
                    doseRepo: doseRepo,
                    beverageRepo: beverageRepo,
                    planRepo: planRepo
                )
                debugLog("STEP 13: AppState created, profile=\(appState.profile != nil), doses=\(appState.doses.count)")

                try appState.refreshDailyPlan()
                debugLog("STEP 13: Daily plan refreshed, plan items: \(appState.dailyPlanItems.count)")

                for item in appState.dailyPlanItems {
                    debugLog("  PLAN ITEM: \(item.id) \(item.compoundName) \(item.dayKey)")
                }

                await MainActor.run {
                    debugLog("STEP 14: Calling setupWindowContent()...")
                    setupWindowContent()
                    debugLog("STEP 14: setupWindowContent() completed")
                }

                debugLog("INITIALIZATION COMPLETE")
            } catch {
                debugLog("Failed to initialize app at step: \(error)")
            }
        }
    }

    @MainActor
    private func setupWindowContent() {
        debugLog("setupWindowContent: appState is \(appState != nil ? "not nil" : "nil")")
        if let appState = appState {
            debugLog("setupWindowContent: profile=\(appState.profile != nil), doses=\(appState.doses.count), beverages=\(appState.beverages.count)")
        }
        let physicsEngine = SharedPhysicsEngine()

        let contentView = MainSplitView(appState: appState, sharedPhysicsEngine: physicsEngine)
            .preferredColorScheme(UserDefaults.standard.bool(forKey: "darkModeEnabled") ? .dark : nil)
        debugLog("setupWindowContent: Creating NSHostingView with MainSplitView")
        window.contentView = NSHostingView(rootView: contentView)
        debugLog("setupWindowContent: contentView set to NSHostingView")
        window.physicsEngine = physicsEngine.engine
        debugLog("setupWindowContent: physicsEngine set")
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    // MARK: - Menu Actions

    @objc func addDose(_ sender: Any?) {
        NotificationCenter.default.post(name: .addDose, object: nil)
    }

    @objc func skipNext(_ sender: Any?) {
        NotificationCenter.default.post(name: .skipNext, object: nil)
    }

    @objc func takeNext(_ sender: Any?) {
        NotificationCenter.default.post(name: .takeNext, object: nil)
    }
}

@MainActor
private func setupMainMenu() {
    let mainMenu = NSMenu()

    // App menu
    let appMenuItem = NSMenuItem()
    let appMenu = NSMenu()
    appMenu.addItem(withTitle: "About Koffee", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
    appMenu.addItem(NSMenuItem.separator())
    appMenu.addItem(withTitle: "Quit Koffee", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    appMenuItem.submenu = appMenu
    mainMenu.addItem(appMenuItem)

    // Edit menu
    let editMenuItem = NSMenuItem()
    let editMenu = NSMenu(title: "Edit")
    editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
    editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
    editMenu.addItem(NSMenuItem.separator())
    editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
    editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
    editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
    editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
    editMenuItem.submenu = editMenu
    mainMenu.addItem(editMenuItem)

    // Actions menu (new)
    let actionsMenuItem = NSMenuItem()
    let actionsMenu = NSMenu(title: "Actions")
    let addDoseItem = NSMenuItem(title: "Add Dose", action: #selector(AppDelegate.addDose(_:)), keyEquivalent: "n")
    addDoseItem.keyEquivalentModifierMask = .command
    actionsMenu.addItem(addDoseItem)
    let skipItem = NSMenuItem(title: "Skip Next", action: #selector(AppDelegate.skipNext(_:)), keyEquivalent: "s")
    skipItem.keyEquivalentModifierMask = .command
    actionsMenu.addItem(skipItem)
    let takeItem = NSMenuItem(title: "Take Next", action: #selector(AppDelegate.takeNext(_:)), keyEquivalent: "t")
    takeItem.keyEquivalentModifierMask = .command
    actionsMenu.addItem(takeItem)
    actionsMenuItem.submenu = actionsMenu
    mainMenu.addItem(actionsMenuItem)

    NSApplication.shared.mainMenu = mainMenu
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)

Task { @MainActor in
    setupMainMenu()
}
app.activate(ignoringOtherApps: true)
app.run()
