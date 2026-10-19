# Koffee

macOS app for calculating optimal caffeine intake, built with SwiftUI + GRDB.

```bash
./build.sh      # Generate + build
./run.sh        # Build + run (opens Koffee.app)
./test.sh       # Full test suite (LiquidContainer + app)
./tools/gate.sh --full  # House gates (build, tests, swiftlint, structure)
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
├── Domain/            # Scheduling helpers (no PK math here)
│   ├── BiologicalIntervention.swift
│   ├── BiologicalSex.swift
│   ├── Constants.swift
│   └── DateHelper.swift
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
| DoseModel / BeverageModel | Data/Models/ | GRDB records |
| `projectBedtimeCaffeine` | Data/Models.swift | THE bedtime-projection funnel (one decay core) |
| `calculateCaffeineLevel` | Data/Models.swift | Half-life decay core (halfLife * metabolism multiplier) |
| MetabolismRate / Sensitivity | Data/ | Half-life direction + bedtime limits |
| DoseRepository | Data/Repositories/ | Dose CRUD |

## Database Tables

`doses`, `daily_plan_items`, `user_profile`, `beverages`

## Scripts

| Command | What it does |
|---------|--------------|
| `./build.sh` | xcodegen + build |
| `./run.sh` | Build + open Koffee.app |
| `./test.sh` | LiquidContainer + app test suites |
| `./clean.sh` | Remove DerivedData + build artifacts |
| `tools/gate.sh --full` | House gates (structure, swift, lint, shipped architectures) |
| `tools/arch_gate.sh` | Build Release, then check the shipped Mach-O against the declared `ARCHS` |
| `tools/arch_gate_test.sh` | Calibration: prove the architecture gate can still fail |