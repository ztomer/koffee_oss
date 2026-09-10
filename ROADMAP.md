# Koffee Roadmap — shipped through v0.1.0

Standing constraints: everything data-driven, nothing hardcoded (no per-item
lookup tables; derive from beverages.json, GRDB, or computed PK values).
House gates stay green: build, 162 tests, `swiftlint --strict`, user-POV
screenshot for every visual change, greyscale check for every new distinction.

## Shipped (context — see `git log`)

- Coffee-only strip, one decay funnel (`projectBedtimeCaffeine`), fixed
  metabolism direction, panel pass (human words, mg chart, labeled legend).
- v0.1.0: sheet consequence lines + USUAL tag (`TimelineSheets.swift`,
  `usualBeverageId` / `projectedBedtimeCaffeine` on `AppState`); oracle voice
  + bounce (`oracleLine` + `.symbolEffect`); history streaks + "Log coffee"
  button (`consecutiveDayStreak` / `streakLine`, posts `.addDose`); notifications
  live preview + permission wiring (`nextNudgeLine`, `requestPermission` on
  first enable); liquid exposure + dose kick (wash removed, `containerAccelX`
  kick, `bubbleCount` scaling with `fillRatio`).

## Recurring gates (not features — run them every pass)
- Greyscale single-channel check on every new visual distinction.
- User-POV screenshot at native pixels for every visual change.
- New tests must go red first (break the code once) before trusting green.
