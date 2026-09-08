# Koffee Architecture

Koffee is a native macOS application for calculating optimal caffeine intake with scientific rigor.

## Tech Stack

- **UI**: SwiftUI (macOS 26.0+)
- **Data**: GRDB SQLite with ValueObservation for reactive updates
- **Physics**: LiquidContainer package for liquid simulation

## Architecture

```
Views → AppState (ObservableObject) → Repositories → GRDB SQLite
         ↑ @Published properties      ↑ ValueObservation
```

### Core Principles

1. **Single Source of Truth**: All data flows through GRDB via AppState — no ad-hoc solutions, no dual writes
2. **Views read/write via AppState**: No direct database access from views
3. **Reactivity**: GRDB ValueObservation → @Published → SwiftUI auto-updates

### Data Flow Rules

- **Reads**: Views read `@Published` properties from `AppState`
- **Writes**: Views call `AppState` methods (e.g., `try appState.addDose(...)`)
- **No dual writes**: One write operation, one database table

## Directory Structure

```
Koffee/
├── App/main.swift                    # App entry point
├── Data/
│   ├── Database/DatabaseManager.swift  # GRDB setup, migrations
│   ├── Models/AllModels.swift       # GRDB record types
│   ├── Repositories/AllRepositories.swift  # ValueObservation repos
│   ├── AppState.swift              # Single ObservableObject coordinator
│   └── BeverageManager.swift        # Beverage loading
├── Domain/
│   ├── PharmacokineticEngine.swift    # Michaelis-Menten kinetics
│   └── BiologicalIntervention.swift   # Caffeine timeline events
├── Services/
│   ├── NotificationManager.swift   # Caffeine cutoff + morning reminders
│   └── MenuBarManager.swift
├── UI/
│   ├── Core/MainSplitView.swift, Design.swift
│   ├── Views/*.swift
│   └── UnifiedChartView.swift   # Caffeine timeline chart
└── beverages.json                  # Beverage catalog (caffeine sources only)
```

## Database Tables

| Table | Purpose |
|-------|---------|
| `user_profile` | Weight, sensitivity, wake/sleep times, caffeine stack membership |
| `beverages` | Beverage catalog |
| `doses` | Logged caffeine doses |
| `daily_plan_items` | Caffeine schedule items |

## Key Types

| Type | Layer | Purpose |
|------|------|--------|
| `DoseModel` | Data | GRDB record for doses |
| `BeverageModel` | Data | GRDB record for beverages |
| `AppState` | Data | ObservableObject coordinator |
| `Dose` | Domain | In-memory caffeine dose with compound + isPlanItem |
| `NootropicCompound` | Domain | Caffeine-only compound enum (PK constants, timing, color) |
| `CaffeineCalculator` | Domain | Caffeine calculations |

## MVC Compliance

Views MUST use AppState methods for data access:

```swift
// ✓ Correct
@ObservedObject var appState: AppState
let todayDoses = appState.dosesForDate(now)
appState.addDose(...)

// ✗ Wrong
appState.doses.filter { ... }           // In-memory filter
appState.doses.first(where: ...)    // Manual find
repo.write(...)                   // Direct repo access
```

## Date Filtering Pattern

Repositories fetch ALL data (needed for history). AppState accessors MUST filter by date:

```swift
// ✓ Correct - filters by today's date
var pendingPlanItemsToday: [DailyPlanItemModel] {
    let today = DateHelper.calendar.startOfDay(for: Date())
    let tomorrow = DateHelper.calendar.date(byAdding: .day, value: 1, to: today)!
    return dailyPlanItems.filter {
        $0.status == .pending && $0.scheduledTime >= today && $0.scheduledTime < tomorrow
    }
}

// ✗ Wrong - returns ALL pending items from every date
var pendingPlanItemsToday: [DailyPlanItemModel] {
    dailyPlanItems.filter { $0.status == .pending }
}
```

## Build Commands

```bash
./build.sh      # Generate + build
./run.sh        # Build + run
xcodebuild test # Run tests
```

## File Size Rules

- Max 500 lines per file
- If larger, extract types to separate files

## Layout Troubleshooting

- **Squished/wrapped content**: Check for nested VStack in HStack, hardcoded frame widths
- **First approach**: Simplify layout - single-level stacks with proper spacing
- **Use LazyVStack for lists**: With explicit ForEach over sorted data
- **Test at multiple widths**: Resize window to verify responsive layout