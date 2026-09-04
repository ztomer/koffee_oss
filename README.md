# Koffee

macOS app for calculating optimal caffeine intake, built with SwiftUI + GRDB.

```bash
./build.sh        # Build
open Koffee.xcodeproj  # Open in Xcode
```

## Project Tree

```
Koffee/
├── App/               # Entry point
├── Data/
│   ├── Database/     # GRDB setup
│   ├── Models/        # GRDB models
│   ├── Repositories/  # Data access layer
│   └── *.swift        # Core types
├── Domain/            # Business logic
│   ├── CaffeineCalculator.swift
│   ├── PharmacokineticEngine.swift
│   └── StackOptimizerEngine.swift
├── Services/          # Notifications, auth, etc
└── UI/
    ├── Core/          # MainSplitView, Design
    └── Views/         # All SwiftUI views
```

## Data Flow

```
View -> AppState -> Repository -> GRDB SQLite
                \-> @Published -> View (reactive)
```

## Key Types

| Type | Location | Purpose |
|------|----------|---------|
| AppState | Data/ | Single source of truth |
| NootropicCompound | Data/ | Stack compounds enum |
| PharmacokineticEngine | Domain/ | Caffeine PK calc |
| DoseRepository | Data/Repositories/ | Dose CRUD |

## Database Tables

`doses`, `supplement_logs`, `hydration_entries`, `exercise_logs`, `daily_plan_items`, `user_profile`, `beverages`

## Scripts

| Command | What it does |
|---------|--------------|
| `size_report.sh` | File sizes, count >500 |
| `find_type.sh Type` | Where type defined |
| `grep.sh "pat"` | Search with context |
| `quick_build.sh` | Fast compile check |
| `project_overview.sh` | Structure summary |
| `dep_graph.sh` | Dependencies |