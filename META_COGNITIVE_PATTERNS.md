# Meta-Cognitive Patterns for Koffee Development

## Core Principles

### 1. Single Source of Truth
- **All data flows through GRDB SQLite via `AppState`**
- **Never**: Dual writes, in-memory copies, direct database access from views
- **Test**: If a view needs data not in `AppState`, add it to `AppState` — don't create workarounds
- **Pattern**: `View → AppState → Repository → GRDB` (read) / `View → AppState method → Repository → GRDB` (write)

### 2. Plan → Test → Document
1. **Plan**: Identify root cause, design fix, determine files
2. **Test**: Write tests first (TDD), then implement
3. **Verify**: All existing tests pass + new tests pass
4. **Document**: Update `ARCHITECTURE.md` and `AGENTS.md` if architecture changes

### 3. Never Guess — Always Trace
- **Do not guess the root cause of bugs.** Add tracing, logging, and use the data to identify the actual cause.
- **Do not guess the root cause of performance issues.** Use Instruments (Time Profiler, Allocations, Leaks) or other standard profilers to get empirical data.
- When something doesn't work, add step-by-step logging at each stage of the data flow. Read the logs. Let them tell you where it breaks.
- When something is slow, profile it. Don't speculate about which function is the bottleneck.

### 3. Investigation Before Implementation
- **Always trace data flow** before making changes
- Use `rtk grep` to find all references to affected types/methods
- Check both read and write paths
- Verify reactive chain: `ValueObservation → @Published → @ObservedObject → View`

### 4. Date Filtering in List Data
- When a repository fetches ALL data (for history), AppState accessors MUST filter by date
- **Never**: Return unfiltered lists from AppState properties that should be "today's"
- **Pattern**: `var itemsToday: [Item] { items.filter { $0.date >= today && $0.date < tomorrow } }`
- **Example**: `pendingPlanItemsToday` filters scheduleTime, not just status

### 5. Layout Troubleshooting
- **Squished/wrapped content**: Check for nested VStack in HStack, hardcoded frame widths
- **First approach**: Simplify layout - single-level stacks with proper spacing
- **Use LazyVStack for lists**: With explicit ForEach over sorted data, not grouped/enumerated
- **Test at multiple widths**: Resize window to verify responsive layout

## Testing Patterns

### In-Memory Database Setup
```swift
// Use DatabaseQueue() for in-memory DB - no file I/O
let db = try DatabaseQueue()

// Set up schema with migrator
var migrator = DatabaseMigrator()
migrator.registerMigration("v1_initial") { db in
    try db.create(table: "my_table") { t in ... }
}
try migrator.migrate(db)

// Create repos and AppState
let repo = MyRepository(db: db)
let appState = AppState(repo: repo, ...)
```

### Testing Reactive Updates
```swift
// Use Combine expectations to test ValueObservation propagation
let exp = expectation(description: "data updated")
exp.assertForOverFulfill = false
let cancellable = appState.$myData.dropFirst().sink { data in
    if data.count > 0 { exp.fulfill() }
}
try appState.addItem(...)
wait(for: [exp], timeout: 2.0)
cancellable.cancel()
```

### Test Organization
- One test class per domain (DoseRepositoryTests, HydrationRepositoryTests, etc.)
- Each test class has its own `setUp()` with fresh in-memory DB
- Regression tests for every bug fixed
- Integration tests for cross-component data flow

## Architecture Patterns

### Repository Pattern
```swift
final class MyRepository: ObservableObject {
    private let db: DatabaseQueue
    @Published private(set) var items: [MyModel] = []
    private var cancellables = Set<AnyCancellable>()
    
    init(db: DatabaseQueue) {
        self.db = db
        startObserving()
    }
    
    private func startObserving() {
        ValueObservation
            .tracking { db in try MyModel.fetchAll(db) }
            .publisher(in: db, scheduling: .immediate)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] items in self?.items = items }
            )
            .store(in: &cancellables)
    }
}
```

### AppState Coordinator
```swift
@MainActor
final class AppState: ObservableObject {
    @Published private(set) var items: [MyModel] = []
    private let repo: MyRepository
    private var cancellables = Set<AnyCancellable>()
    
    init(repo: MyRepository) {
        self.repo = repo
        self.items = repo.items
        repo.$items
            .receive(on: DispatchQueue.main)
            .sink { [weak self] items in self?.items = items }
            .store(in: &cancellables)
    }
    
    func addItem(...) throws {
        try repo.add(...)
    }
}
```

### View Pattern
```swift
struct MyView: View {
    @ObservedObject var appState: AppState  // NEVER @State
    @State private var localState: String = ""  // Only for local UI state
    
    var body: some View {
        // Read from appState, write through appState methods
    }
}
```

## File Management

### When to Split Files
- **Views**: Split when file exceeds ~200 lines
- **Tests**: One file per test class
- **Models**: Group related models in one file (AllModels.swift)
- **Repositories**: All repos in AllRepositories.swift (protocols + implementations)

### File Naming Conventions
- Models: `MyModel.swift` or `AllModels.swift`
- Repositories: `AllRepositories.swift`
- Views: `MyFeatureView.swift`
- Domain logic: `MyEngine.swift`
- Tests: `MyFeatureTests.swift`

### Dead Code Removal
- Delete deprecated files immediately after migration
- Remove unused imports
- Delete old test files that test deprecated architecture
- Update `project.yml` if removing targets

## Error Handling

### Repository Methods
- Throw `RepositoryError` for validation failures
- Throw `RepositoryError.notFound` for missing items
- Throw `RepositoryError.validationFailed` for invalid input

### AppState Methods
- Throw `AppError` wrapping repository errors
- Use `try?` for non-critical UI operations (logging, optional updates)
- Critical operations (saving profile, adding doses) should propagate errors

### View Error Handling
- Use `try?` for user-triggered actions (button taps, picker changes)
- Show alerts for critical failures
- Silent failures acceptable for non-critical UI updates

## Data Flow Patterns

### Plan vs Actuals
- **Plan**: `DailyPlanItemModel` - what should happen today
- **Actuals**: `DoseModel`, `SupplementLogModel`, etc. - what actually happened
- **Approval**: Plan item → approved → logs to actuals
- **Disapproval**: Plan item → pending → unlogs from actuals
- **Future items**: Regenerate when stack changes (if autoRefreshPlan enabled)
- **Past items**: Locked, cannot be changed by plan refresh

### Composite Dashboard Chart
- **Past**: Actual logged doses
- **Future**: Actuals + planned doses
- **Normalization**: Convert to % of safe limits
- **Y-axis**: Extend above 100% if needed, with red warning area

### History Computation
- Computed on-demand from actual data
- No separate history table
- Include timestamps, amounts, durations
- Filter by date using SQL-level filtering

## Migration Patterns

### Stringly-Typed → Enum
1. Create enum with `String` raw value
2. Add computed property to model: `var myEnum: MyEnum { get { MyEnum(rawValue: status) ?? .default } set { status = newValue.rawValue } }`
3. Update repository method signatures to use enum
4. Update AppState methods to use enum
5. Update UI to use enum
6. Update tests to use enum
7. Build and test after each step

### SwiftData → GRDB
1. Create GRDB models with `FetchableRecord`, `PersistableRecord`
2. Add CodingKeys for snake_case column mapping
3. Create repositories with ValueObservation
4. Create AppState coordinator
5. Migrate UI from `@Query` to `@ObservedObject var appState`
6. Delete SwiftData models and containers
7. Update all tests

## Build/Test Loop

### After Every Change
```bash
xcodegen generate
xcodebuild -project Koffee.xcodeproj -scheme Koffee -configuration Debug build
xcodebuild test -project Koffee.xcodeproj -scheme KoffeeTests -destination 'platform=macOS'
```

### Common Issues
- **LSP errors**: Usually stale, ignore if build succeeds
- **Test failures**: Check for string vs enum mismatches, missing schema columns
- **Build failures**: Check for missing imports, duplicate declarations
- **App crashes**: Check for nil modelContext, race conditions in init

## Documentation Updates

### When to Update ARCHITECTURE.md
- New tables added
- New repositories created
- Data flow changes
- New computed properties in AppState
- New domain algorithms

### When to Update AGENTS.md
- Build/test commands change
- File structure changes
- New patterns or conventions
- Deprecated code removed

### When to Update CONTRIBUTING.md
- New common pitfalls discovered
- New patterns established
- Testing strategies refined

## Decision Framework

### Before Making Changes
1. What's the root cause? (not the symptom)
2. What's the single source of truth for this data?
3. How will this change affect the reactive chain?
4. What tests need to be added/updated?
5. What documentation needs updating?

### When Stuck
1. Trace the data flow from UI → AppState → Repository → DB
2. Check if the issue is in the read path, write path, or both
3. Verify the reactive chain is connected (ValueObservation → @Published → @ObservedObject)
4. Check for race conditions (async init, delayed configuration)
5. Add logging to trace the actual data flow

## Common Pitfalls

### ✗ Don't
- Use `@State var appState: AppState` (use `@ObservedObject`)
- Bypass AppState to access repositories directly from views
- Store computed data in the database (compute on-demand)
- Dual-write to multiple data stores
- Use in-memory filtering for date queries (use SQL-level)
- Create workarounds when data isn't in AppState (add it to AppState)

### ✓ Do
- Use `@ObservedObject var appState: AppState` in all views
- Route all data through AppState methods
- Compute summaries, curves, history on-demand
- Write once to the database, let ValueObservation propagate
- Use SQL-level date filtering
- Add missing data to AppState instead of creating workarounds
