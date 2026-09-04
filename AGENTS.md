# Agent Guidelines for Koffee

Koffee is a native macOS app for calculating optimal caffeine intake, built with SwiftUI + GRDB.

## Core Rules

### 1. Single Source of Truth
- All data flows through GRDB SQLite via `AppState` — no ad-hoc solutions
- Views read from `@Published` properties, write via `AppState` methods
- If view needs data not in AppState, add it to AppState — don't create workarounds

### 2. MVC Compliance
```swift
// ✓ Correct
@ObservedObject var appState: AppState
let doses = appState.dosesForDate(now)

// ✗ Wrong - in-memory filter
appState.doses.filter { ... }
```

### 3. Never Guess — Always Trace
- Add tracing/logging to identify root cause
- Use Instruments for performance issues

### 4. Plan → Test → Document
1. Identify root cause
2. Write tests first (TDD)
3. Implement fix
4. Verify all tests pass

## Build Commands

```bash
./build.sh      # Generate + build
./run.sh        # Build + run
xcodebuild test # Run tests
xcodegen generate
```

## File Analysis

```bash
rtk wc -l Koffee/**/*.swift | sort -rn | head -10   # File sizes
rtk grep "pattern" Koffee/                         # Find code
```

## Testing

```bash
xcodebuild test -project Koffee.xcodeproj -scheme KoffeeTests -destination 'platform=macOS'
```

## Common Pitfalls

- ✗ `@State var appState: AppState` → ✓ `@ObservedObject var appState: AppState`
- ✗ Bypassing AppState to access repositories
- ✗ Storing computed data in DB
- ✗ In-memory date filtering → Use SQL-level filtering
- ✗ AppState date-accessor without date filter → Should filter to today/tomorrow
- ✗ Hardcoded frame widths in nested stacks → Layout squishing on resize

## Architecture

See `ARCHITECTURE.md` for full details.