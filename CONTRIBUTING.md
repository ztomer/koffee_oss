# Contributing to Koffee

## Quick Start

```bash
./build.sh      # Generate Xcode project and build
./run.sh        # Build and run the app
xcodegen generate    # Regenerate Xcode project from project.yml
open Koffee.xcodeproj
```

### Running Tests
```bash
cd LiquidContainer && rtk swift test                              # LiquidContainer tests
xcodebuild test -project Koffee.xcodeproj -scheme KoffeeTests -destination 'platform=macOS'  # App tests
```

## Architecture Rules

### 1. Single Source of Truth
- **All data flows through GRDB SQLite via `AppState`**
- Views read `@Published` properties from `AppState`
- Views write through `AppState` methods (e.g., `try appState.addDose(...)`)
- No direct database access from views
- No bypassing repositories
- If a view needs data that isn't in `AppState`, add it to `AppState`

### 2. View Patterns
- All views use `@ObservedObject var appState: AppState` (NOT `@State`)
- Local UI state uses `@State`
- Bindings to profile fields use `Binding(get:set:)` with `saveProfile`
- Never mutate `appState` properties directly (except through methods)

### 3. Repository Pattern
- Each repository wraps a single GRDB table
- Uses `ValueObservation` → `@Published` for reactivity
- Implements a protocol for testability
- Provides CRUD methods with validation
- Date filtering is SQL-level, not in-memory

### 4. Error Handling
- Repository methods throw `RepositoryError`
- `AppState` methods throw `AppError`
- Views use `try?` for non-critical operations (logging, UI updates)
- Critical operations (saving profile, adding doses) should handle errors properly

### 5. Testing
- All tests use in-memory GRDB databases (`try DatabaseQueue()`)
- No file I/O, no mocking
- Write tests first (TDD), then implement
- Regression tests for every bug fixed
- Integration tests for cross-component data flow

## Adding a New Feature

### Adding a New Data Type
1. Add GRDB model in `Koffee/Data/Models/`
2. Add table to migration in `DatabaseManager.swift`
3. Add repository in `AllRepositories.swift`
4. Add to `AppState` (property + observation + methods)
5. Add tests

### Adding a New View
1. Create file in `Koffee/UI/Views/`
2. Use `@ObservedObject var appState: AppState`
3. Read from `appState` properties, write through `appState` methods
4. Add to `MainSplitView.detailContent` or appropriate parent

### Adding a Test
1. Add to `KoffeeTests/Data/DataLayerTests.swift`
2. Use `DatabaseQueue()` for in-memory DB
3. Set up schema with `DatabaseMigrator`
4. Create repositories and `AppState`
5. Test the behavior, not the implementation

## Common Pitfalls

### Don't use `@State` for AppState
```swift
// ✗ WRONG - won't observe changes
@State var appState: AppState

// ✓ CORRECT - observes @Published changes
@ObservedObject var appState: AppState
```

### Don't bypass AppState
```swift
// ✗ WRONG - direct repo access from view
try doseRepo.add(...)

// ✓ CORRECT - through AppState
try appState.addDose(...)
```

### Don't use in-memory filtering for dates
```swift
// ✗ WRONG - filters in memory
doses.filter { $0.timestamp >= start && $0.timestamp < end }

// ✓ CORRECT - SQL-level filtering
try doseRepo.dosesForDate(date)
```

### Don't dual-write
```swift
// ✗ WRONG - writes to two places
try doseRepo.add(...)
doses.append(newUserDose)

// ✓ CORRECT - single write, ValueObservation updates @Published
try doseRepo.add(...)
// AppState.doses updates automatically via ValueObservation
```

## File Structure

```
Koffee/
├── App/main.swift                    # Entry point, AppDelegate
├── Data/
│   ├── Database/DatabaseManager.swift  # GRDB setup, migrations
│   ├── Models/                         # GRDB models
│   ├── Repositories/AllRepositories.swift  # All repos
│   ├── AppState.swift                  # Coordinator
│   └── BeverageManager.swift           # Beverage loading
├── Domain/                             # Pure business logic
├── Services/                           # Notifications, menu bar
└── UI/
    ├── Core/MainSplitView.swift        # Navigation shell
    ├── Views/                          # Feature views
    └── ...                             # Components, charts

KoffeeTests/Data/DataLayerTests.swift   # All tests
```

## Code Style
- No comments unless explaining non-obvious behavior
- Short, focused functions
- Swift 6 concurrency where applicable
- `@MainActor` on all UI-related code
- Use `try?` only for non-critical UI operations
