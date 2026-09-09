# Koffee Roadmap — the goal is to implement everything below

Standing constraints: everything data-driven, nothing hardcoded (no per-item
lookup tables; derive from beverages.json, GRDB, or computed PK values).
House gates stay green: build, 147+ tests, `swiftlint --strict`, user-POV
screenshot for every visual change, greyscale check for every new distinction.

## Shipped (context — see `git log`)

- Coffee-only strip, one decay funnel (`projectBedtimeCaffeine`), fixed
  metabolism direction, panel pass (human words, mg chart, labeled legend).
  Head: `0c6fea4`.

## 1. Sheet consequence lines + USUAL tag
File: `Koffee/UI/Views/TimelineSheets.swift` (+ dose counts via `AppState.doses`).
Under each beverage row, one live line from real data:
`projectBedtimeCaffeine(today doses + this dose)` → e.g. "bedtime 32mg · Sleep
ready" (green) / "…68mg · Over" (red), reusing dashboard bands. Tag the
most-logged `beverageId` (count over `doses`, ties → most recent) with "USUAL".
No per-drink tables; category glyph stays.
Verify: screenshot sheet with 1+ logged doses; row lines match dashboard math.

## 2. Oracle voice + motion
File: `Koffee/UI/Views/DashboardView.swift` (oracle banner).
Per-state copy, numbers stay honest: Sleep ready → thanks-line; Monitor →
wired-line; Over → put-the-pot-down line. Pair with `.symbolEffect(.bounce,
value: bedtimeStatusTitle)` on the state icon.
Verify: screenshot all three states (log doses to drive each); no emoji, copy
states bedtime mg like the current sentence does.

## 3. History streaks + empty-state action
File: `Koffee/UI/Views/HistoryView.swift`.
Streak line from `dosesInRange` consecutive-day counts (e.g. "3 mornings in a
row") shown when `doseCount > 0`; empty state gets a "Log coffee" button that
posts `.addDose` through the existing funnel. Dots already encode risk/size.
Verify: screenshot streak + empty state with button; button opens the sheet.

## 4. Notifications live preview
Files: `Koffee/UI/Views/NotificationsView.swift`, `Koffee/Services/NotificationManager.swift`.
SCHEDULED card shows a live line from the real schedule (next pending plan
item or computed cutoff: "Next nudge: 13:30 cutoff"), or a warm empty line.
Blocked sub-item: no permission flow is wired — wire `requestPermission()` on
first toggle enable before any "send test nudge" work.
Verify: screenshot with and without a pending item; no dead labels.

## 5. Liquid exposure + dose kick
File: `Koffee/UI/Views/DashboardView.swift` (+ `BubbleGenerator` API as-is).
Remove the full-width `.ultraThinMaterial` wash over `LiquidContainerView`
(cards keep their own backgrounds); on dose-count increase, kick
`containerAccelX` and scale idle bubble rate with `fillRatio` using the
existing generator/timer. No new systems.
Verify: screenshot shows liquid crisply; log a dose, confirm motion response;
greyscale re-check (new motion must not carry distinctions).

## 6. Cut the release
Interrupted 2026-09-08. Steps: re-run full gate on a clean tree, exercise the
real binary (all four panes + log/skip/take paths), push `main`, tag annotated
with notes (lead with behavior corrections: metabolism direction, history
bedtime now real, toolbar bedtime now live), verify tag on origin.

## 7. Recurring gates (not features — run them every pass)
- Greyscale single-channel check on every new visual distinction.
- User-POV screenshot at native pixels for every visual change.
- New tests must go red first (break the code once) before trusting green.
