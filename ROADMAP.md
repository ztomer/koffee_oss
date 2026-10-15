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
program") is the reference for every Phase 0b item below; port the corrected
NUMBERS and their citations, never BigKoff's code.

Standing constraints: everything data-driven, nothing hardcoded (derive from
`beverages.json`, GRDB, or computed PK values). House gates stay green: build,
181 tests, `swiftlint --strict`, no compiler warnings, user-POV screenshot for
every visual change, greyscale check for every new distinction, and a new test
must go red once before it is trusted green.

**State (measured 2026-10-15):** v0.1.0; `main` is in sync with `origin/main`.
`tools/gate.sh --full` is **green** — Phase 0 closed it 2026-10-14 and the
gate has stayed green since, through K1 (`2542390`), K2 (`bed737d`)
and K3 (`f5a71d7`).

This header used to say the opposite of the Phase 0 section directly beneath it:
it claimed `main` was ahead of `origin/main` (it is not — that was written before
the push landed) and that goh v0.27.0 "turned `tools/gate.sh --full` red",
while Phase 0 recorded the same work as *closed and green at `6129495`*. Both
sentences were stale in opposite directions, which is the worst pairing: the
header is what a reader trusts first.

Phase 1's G1 also inherited a false premise — "coverage floor not set yet"
read as a decision deferred, when setting one had been **impossible** since goh's
xcode coverage reader broke. See G1.

## Phase 0 — wire in goh 0.27.0: closed 2026-10-14

`tools/gate.sh --full` green at `6129495`, pushed (pre-push 46 s).

- **W.1** `no early-exit pipe under pipefail` (11 sites; five unused scripts deleted, no seed): `1ef235c`
- **W.2** `--full` runs `xcodegen generate` before the swift gate, green in a fresh worktree: `4f948c4`
- **W.3** Scanner floors (10 keys, calibrated red): `6129495`
- **W.4** `main` tracks `origin/main`; pushed: `6129495`

## Phase 0b — the shipped pharmacology that has no support (core rule 8)

Goal: no number or advice Koffee shows contradicts the evidence. Correctness
outranks keeping a number stable; state each user-visible change's magnitude in
its commit. Exit: K1-K5 closed, each with a red-first test. **K1 (2542390),
K2 (bed737d) and K3 (f5a71d7) are closed.** Size **M**, one session.

**K1. The daily ceiling exceeds 400 mg for "low sensitivity" — DONE.**
`AppState.dailyCaffeineLimit` was `Sensitivity.multiplier * 400` and `.low` has multiplier 1.2,
so a user who described themselves as low-sensitivity was shown **480 mg/day as safe**.

The fix splits two things that were welded together:

  * the **ceiling** is EFSA's adult population limit (400 mg; 200 mg single doses). Nothing in
    the app raises it — not sensitivity, not weight, not a declared habit. It is now
    `CaffeineConstants.dailyCeilingMg`, named once, with the citation.
  * **`multiplier` is a metabolism term.** It still drives `safeCaffeineAtBedtime` and the decay
    model, where clearance rate is exactly the right input. Applied to a population ceiling it
    was the right quantity in the wrong place — the same shape as a clearance rate driving a
    dosage.

Deliberately **not** user-tunable, and deliberately not lowered for high sensitivity either. The
first draft of the test argued a fast metabolizer is a reason to be more conservative and left
the door open at 320 mg; the implementation closed it, because "how fast do I clear caffeine" is
not a safety margin and guessing one invents a number no source supports. `multiplier` is
untouched.

The number is now a pure static function of the sensitivity string, so it is testable without a
database and a profile row — a safety claim that can only be checked by standing up the whole app
is a claim nobody checks.

**Red first, and for the right reason:** all four tests failed with `("480.0") is not equal to
("400.0")`, which is the defect stated as a number.

**An existing test had pinned the defect.** `AppStateTests.testDailyCaffeineLimitFollowsSensitivity`
asserted `0.8 * 400`, i.e. that a high-sensitivity user gets 320 mg — right only if the multiplier
may scale the ceiling at all. Updated to 400, keeping what that test was really for: the daily
limit must never become the bedtime limit, which is the distinction with teeth.

User-visible: the dashboard's safe-limit line drops from 480 mg to 400 mg for low-sensitivity
users. Correctness outranks keeping a number stable.


**K2. The "first coffee 90 min after waking" advice has no trial behind it — DONE.**
Four surfaces, not the three the item first counted:

  * `NotificationManager`'s morning body — an inline literal, so unreachable from any test.
  * `TimeConstants.firstDoseDelaySeconds` = 5400, which **actually placed the generated
    plan item at wake + 90 min**. This is the one that mattered: the advice was not
    merely unsound, it was *scheduled*. A user who described their wake time was told at
    breakfast time to wait 90 minutes.
  * `NootropicCompound.explanation`'s "Best taken 90 min after waking to avoid
    afternoon crash".
  * `NootropicCompound.recommendedTimingMinutes` = 90 — **no consumer anywhere in the
    app**, and asserted at 90 by `testCaffeineInAllCompounds`.

No RCT establishes a post-wake delay, and the cortisol rationale is not merely
unsupported but **backwards**: the morning cortisol peak is an adrenal awakening
response that follows waking rather than preceding the first dose, so delaying a dose
dodges nothing. koffee_big grades the claim tier `none` — remove, do not soften.

Fixes in the order that makes each testable: the notification strings moved into a
named `NotificationCopy` enum (copy that cannot be reached from a test cannot be
corrected); `firstDoseDelaySeconds` was **deleted rather than zeroed** — zeroing keeps
the seam that encodes the claim; `recommendedTimingMinutes` was deleted along with the
assertion that pinned it. `NoPostWakeDelayClaimTests` scans the strings the app renders
rather than a list of call sites, over `NootropicCompound.allCases` so a new compound
cannot skip the scan.

**Red first, and for the right reason.** The behavioural test initially failed with **0
plan items**, not the 90-minute offset: `AppState`'s three `@Published` properties each
lag their repository write by one main-queue hop, so reading `dailyPlanItems`
immediately after `refreshDailyPlan()` returns asserts on nothing. A test red for the
wrong reason is worthless. Waiting on `$dailyPlanItems` turned it into *"the caffeine
plan item sits 90 min after wake"* — the defect stated as a number.

Calibrated by planting the claim at a surface the scan had never seen
(`NotificationCopy.morningBody`): red, and it names the surface.

User-visible: the dashboard's first-coffee row moves from wake+90 to wake.

**K3. Fixed cutoff hours 6 / 9 / 12 by sensitivity are unsourced — DONE.**
`Sensitivity.hoursBeforeBedForLastDose` was a table (low 6 h, medium 9 h, high
12 h, × metabolism) driving the cutoff notification and the Notifications
preview. Replaced by `CaffeinePK`.

**The sourcing was the lesser problem. The table was dose-blind.** It drew the
same wall for a 50 mg tea and a 400 mg cold brew. For a medium reader with a
23:00 bedtime it drew 14:00, and a 200 mg dose taken at 14:00 is still

    200 · 0.5^(9/5) = 57.4 mg

at bedtime — above the 50 mg that reader's own threshold says. The app could
report the cutoff respected while its own model put the reader over the line it
drew. koffee_big measured this on 2026-09-08 and deleted the same table; this
fork predates that audit, so it still shipped it.

The replacement is **the longer of two numbers, each with a different warrant**:

  * **the derivation** — hours for THIS dose to decay to THIS reader's threshold
    at THEIR half-life (the exact inverse of `calculateCaffeineLevel`), so the
    `calculateCaffeineLevel`), so the cutoff and the bedtime projection cannot
    disagree by construction.
  * **the Gardiner floor** — the only head-to-head dose-by-timing trial data
    (0 / 47 / 100 / 400 mg → 0 / 0 / 4 / 12 h; `gardiner2024sleep`,
    `gardiner2023sleep`, `efsa2015sleep`). Segments are **linear interpolation**
    and are labelled as presentation rather than finding. Past 400 mg the last
    segment **extends**, it does not clamp: clamping claims knowledge stops
    mattering at the last node.

The longer, never the shorter, never an average. Where the floor binds the
empirics do the work; where the derivation binds the reader's own threshold
does.

Metabolism moved **inside** the half-life instead of being multiplied onto the
resulting hours — it is a clearance rate, so lengthening the half-life is the
correct direction, and it keeps the cutoff consistent with the decay model.

Both consumers now take a dose. `nextNudgeLine` takes `referenceDoseMg`; the
view passes **today's largest logged dose**, falling back to the 95 mg
prospective standard. Never an average — averaging pulls the wall inward, and
conservatism has only one safe direction.

**Red first, and calibrated.** The load-bearing assertion is an invariant, not
a number: after waiting the gap the app draws, the dose is not above the
reader's own threshold at bedtime — across every sensitivity and every dose
from 50 to 400 mg. Reintroducing the retired table fails it five times over,
which is the calibration that proves the check bites.

Two of my own test expectations were wrong before the code was, and both were
corrected in the tests rather than the code: 800 mg on the floor is **22.67 h**,
not 24 (the slope is linear in milligrams, not in log-dose), and the 95 mg
cutoff is **18:23**, not 18:22 (277.8 min truncates to 277, which moves the
wall half a minute earlier — the conservative direction). Stated plainly because
a test agreeing with a broken expectation is how a wrong number gets pinned.

User-visible: the cutoff notification and the Notifications preview move with
the dose. A medium reader, 23:00 bedtime, 95 mg day → **18:23** instead of
14:00. A 400 mg day draws a wall the old table never would have.

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

- **G1. No coverage floor — DONE.** `GOH_SWIFT_COV_MIN=40` in `.gatesrc`, with per-target
  floors in `tools/coverage_floors.jsonc`. Measured on the committed tree: **Koffee.app is
  40.4%** (3186/7889 lines).

  Per-target because the whole-tree number is meaningless here: AppAuth, GRDB, KeychainAccess
  and LiquidContainer are third-party and report 0%, which would drag a total to ~14% and make
  the gate a statement about dependencies rather than about Koffee.

  **It was never "not set yet" — it was settable and could not be set.** Turning the floor on
  went red on a healthy tree, because `check_swift_coverage.py --xcode` was unrunnable: it read
  coverage with `xcresulttool get --format json`, which Xcode now refuses without `--legacy`.
  That is fixed in goh v0.28.1 (`gates_of_heck` `b267e82`), which reads `xccov` instead and keeps
  the object walk as a `--legacy` fallback. This repo's floor is the first in the estate to
  depend on it.

  Two numbers were rejected on the way, both because the gate would have been measuring the
  wrong thing:

  * **60.2%** — counting the `Koffee.xctest` bundle. A test file is ~100% covered by
    definition; it is the thing doing the running. A floor set on that number can be met by
    writing tests that assert nothing. `lib/swift_coverage_scope.py` has said so since
    2026-09-07, and the xcode path had never applied it.
  * **~14%** — including the third-party targets.

  Proven red through this repo's own gate, not by editing the number: with the floor at 60 the
  gate reports `40.4% is under the 60% floor` and names `Koffee.app`. Ratchet up to 95 as
  coverage lands.

- **G2. Xcode build logs are tracked — DONE, and the gap it names is real.**
  `git rm -r --cached DerivedDataTests` — the six tracked files are now zero — and the path is
  in `.gitignore` with a note saying why. The files themselves are untouched on disk; only the
  tracking went.

  The item's fallback applies: **goh has no "no tracked build output" check**, so the gap is
  reported there rather than papered over with a local grep. Only `version-provenance` comes
  close and it is about something else entirely. Recorded in `gates_of_heck`'s `docs/BACKLOG.md`.

- **G3. Seven bare `print(` calls in `Koffee/` — DONE.** Routed through `debugLog()`, which the
  app already used from `Koffee/Data/` and which writes a labelled, timestamped line to
  `/tmp/koffee.log`. The defect was never the call: it was that a cutoff reminder which failed
  to schedule said so on stdout, into whatever was attached, and left **nothing in the log a
  user could send**.

  `debugLog`'s own console echo became `FileHandle.standardError.write` rather than being
  dropped — the live tail is worth keeping, and losing it to satisfy a grep would have been the
  gate dictating behaviour. `rg 'print(' Koffee` is now empty, which is the item's own proof.

  Gated by `tools/no_bare_print.sh`, wired into `tools/gate.sh --full` **before** the swift gate
  so a planted print is caught in seconds instead of after a full `xcodebuild test`. Proved by
  planting one.

  It is a plain grep, comments included, on purpose. Stripping comments first would be friendlier
  and would let a comment quote the call it is discussing for free; here such a comment goes red
  instead — annoying, and the safe direction to fail in, because noticing a print that came back
  is the entire job.

## Phase 2 — product (only after Phase 0b)

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
- koffee_big `FEATURE_PLAN.md` — the evidence archive Phase 0b cites.
- gates_of_heck v0.27.0 Downstream (2026-10-14): hooks reinstalled
  (`57568df`); early-exit pipes (goh counted 11) -> W.1; floors -> W.3. No
  Python, so the stdin gate reads nothing here.
