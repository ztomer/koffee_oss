# Koffee Roadmap

The one forward-looking plan for this repo. Shipped work lives in `git log`;
the previous version of this file is `git show 7cf37e8:ROADMAP.md`.

## What this repo is, and how it relates to koffee_big

Koffee is the **open-source, coffee-only** caffeine tracker for macOS (SwiftUI +
GRDB). It is a FORK of koffee_big's early history (the `koffee-big-ancestor`
remote points at `ztomer/Koffee_big`), flattened to one commit on 2026-09-04 and
stripped to caffeine on 2026-09-08 (`bd2134d`). koffee_big has since become a
different product (BigKoff: cognitive capacity, supplements, an Android
companion, a portable engine). Nothing merges between them in either direction.

The consequence that matters: **this fork was cut BEFORE koffee_big's
2026-09-08 evidence audit**, so it still ships the caffeine numbers that audit
proved wrong. koffee_big's `FEATURE_PLAN.md` evidence archive ("SOTA evidence
program") is the reference for every Phase 0 item below; port the corrected
NUMBERS and their citations, never BigKoff's code.

Standing constraints: everything data-driven, nothing hardcoded (derive from
`beverages.json`, GRDB, or computed PK values). House gates stay green: build,
162 tests, `swiftlint --strict`, no compiler warnings, user-POV screenshot for
every visual change, greyscale check for every new distinction, and a new test
must go red once before it is trusted green.

**State (measured 2026-10-12):** `main` = `origin/main`, v0.1.0, tree clean,
`tools/gate.sh --full` green (structural + swiftlint + xcodebuild test + no
warnings).

## Phase 0 — the shipped pharmacology that has no support (core rule 8)

Goal: no number or advice Koffee shows contradicts the evidence. Correctness
outranks keeping a number stable; state each user-visible change's magnitude in
its commit. Exit: K1-K5 closed, each with a red-first test. Size **M**, one
session.

**K1. The daily ceiling exceeds 400 mg for "low sensitivity".**
`AppState.dailyCaffeineLimit` = `Sensitivity.multiplier` (1.2 / 1.0 / 0.8) x 400,
so a low-sensitivity user is shown 480 mg/day as safe. 400 mg is EFSA's adult
ceiling and is not raised by self-report (koffee_big refuses "any safety limit
scaled by self-report"). *DONE WHEN:* the limit never exceeds 400 mg (200 mg in
pregnancy if that input is ever added); a test pins it for every sensitivity.
User-visible: the dashboard's safe-limit line drops for low-sensitivity users.

**K2. The "first coffee 90 min after waking" advice has no trial behind it.**
Three places: `TimeConstants.firstDoseDelaySeconds` = 5400 places the daily-plan
item; `NotificationManager` says "First coffee in 90 minutes for optimal
cortisol alignment"; the caffeine description says "Best taken 90 min after
waking to avoid afternoon crash". No RCT establishes a post-wake delay and the
cortisol / adenosine rationale is backwards (Antonio et al. 2024, Klaas et al.
2025; koffee_big grades it tier `none`). *DONE WHEN:* no surface states a delay
as guidance or cites cortisol; the plan item sits at wake or the user's own
declared first-cup time; a test scans the strings.

**K3. Fixed cutoff hours 6 / 9 / 12 by sensitivity are unsourced.**
`Sensitivity.hoursBeforeBedForLastDose` (x metabolism) drives the cutoff
notification and the Notifications preview, and ignores dose size — koffee_big
deleted the same table after its own PK showed a 200 mg dose over threshold
while "respecting" the cutoff. *DONE WHEN:* the cutoff is derived per dose by
decaying it through `calculateCaffeineLevel` to the bedtime threshold, floored
by the Gardiner anchors (0 / 47 / 100 / 400 mg -> 0 / 0 / 4 / 12 h; Gardiner
2023 meta-analysis + 2024 crossover), with the citation in data.

**K4. Bedtime residual tiers 25 / 50 / 100 mg: only 100 mg is sourced.**
`Sensitivity.safeCaffeineAtBedtime` and `CaffeineConstants.*BedtimeMg`.
koffee_big's audit found no source for the tiers (efsa2015sleep backs 100 mg).
*DONE WHEN:* the threshold is 100 mg with its citation, and anything stricter is
a user preference the UI names as theirs; `CaffeineConstants` and `Sensitivity`
no longer hold two copies of the same three numbers.

**K5. The interaction-extension model and its dead constants.**
`calculateCaffeineLevel(interactions:)` lengthens caffeine's half-life by
`extensionHours` — the theanine-extends-caffeine model the audit refuted
(theanine has no CYP1A2 effect; Grzegorzewski 2022). No caller passes it after
the coffee-only strip, so it is a seam that encodes a false claim. Dead beside
it: `MathConstants.lTheanineRatio` 1.5, `recoveryPenalty`,
`sleepScoreThreshold`, `lowSleepScoreThreshold`, `deepSleepMinimumMinutes`, and
`PKEngineeringConstants` (Michaelis-Menten Km / Vmax — saturable elimination
needs several times a lethal concentration). *DONE WHEN:* the parameter and
every constant with zero readers are deleted; a test or `rg` gate refuses
`extensionHours` returning.

## Phase 1 — gate holes

Goal: the gate can fail on everything the house rules require. Size **S**.

- **G1. No coverage floor.** `tools/gate.sh` says "Coverage floor not set yet".
  *DONE WHEN:* `GOH_SWIFT_COV_MIN` in `.gatesrc` at the measured value (ratchet
  up to 95), proven red by lowering coverage once.
- **G2. Xcode build logs are tracked.** Six files under `DerivedDataTests/`
  (`.xcactivitylog`, `LogStoreManifest.plist`, `workspace-state.json`) came in
  with the history flatten. *DONE WHEN:* `git rm -r --cached DerivedDataTests`,
  the path ignored, and the house "no tracked build output" check (if goh has
  one) sees it; otherwise report the gap to gates_of_heck.
- **G3. Seven bare `print(` calls in `Koffee/`** (e.g. the cutoff scheduler's
  failure path). Route through the app's `debugLog` / a logger so a failure is
  visible in the log the rest of the app writes. *DONE WHEN:* `rg 'print\('
  Koffee` is empty, gated.

## Phase 2 — product (only after Phase 0)

The 2026-09-08 loop goal ("make this the best coffee intake app in history")
is carried as these concrete items, in koffee_big's competitor-survey order:
every top-rated caffeine app has a caffeine-free-at forecast, a bedtime-level
forecast and quick-log. Size **M** each.

- **P1. "Caffeine-free at" and bedtime forecast** on the dashboard, computed
  through `projectBedtimeCaffeine` (the one funnel) with K3's per-dose cutoff.
- **P2. Quick-log from the menu bar / a widget** for the usual beverage
  (`usualBeverageId` exists).
- **P3. Tolerance as a pharmacodynamic gain, not a clearance change** — only if
  a tolerance input is added; chronic use does not change half-life (Robertson
  1981, Shi 1993). Parked until a user-facing reason exists.

## Recurring gates (run them every pass)

- Greyscale single-channel check on every new visual distinction.
- User-POV screenshot at native pixels for every visual change.
- New tests must go red first (break the code once) before trusting green.

## Sources consolidated (2026-10-12)

- `.opencode/opencode-loop/` — one goal, `ses_f7d27e1f…` "make this the best
  coffee intake app in history" (2026-09-08, `active` but stalled at
  no-progress 1/3 after one turn; v0.1.0 shipped its first round). Carried as
  Phase 2. The goal file and `loop.log` were TRACKED despite two earlier
  "Untrack opencode-loop" commits, because `.gitignore` never listed
  `.opencode/`; removed and ignored in this commit.
- Claude memory / desktop sessions — none for this repo (searched "koffee").
- Antigravity, Gemini CLI — none for this repo.
- git — `main` only, level with `origin`; no worktrees. A stale
  `.goh-tree.lock` (2026-09-26, holder pid long dead, globally ignored) was
  trashed; the gate had already run over it.
- `RUSTIFICATION_ROADMAP.md` (Projects root) — lists `koffee_oss` as
  never-in-scope (stays native Swift). No item.
- `ROADMAP-consolidated.md` (Projects root) — no koffee_oss entries.
- koffee_big `FEATURE_PLAN.md` — the evidence archive Phase 0 cites.
