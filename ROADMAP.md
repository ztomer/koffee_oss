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
226 tests, `swiftlint --strict`, no compiler warnings, user-POV screenshot for
every visual change, greyscale check for every new distinction, and a new test
must go red once before it is trusted green.

**State (measured 2026-10-19):** v0.2.0 released (Phase 0b, 0c, 0d); `main` is in sync with `origin/main`.
`tools/gate.sh --full` is **green** — Phase 0 closed it 2026-10-14 and the
gate has stayed green since, through all five Phase 0b items — K1 (`2542390`),
K2 (`bed737d`), K3 (`f5a71d7`), K4 (`a6a9470`), K5 (`2aeb51d`) — and through
the architecture gate (Phase 1, G6).

**Found and fixed 2026-10-16:** the app's launch path deleted and recreated the user's profile on
every launch, and because the test host is the app, a push did it too —
`tools/gate.sh --full` was green over it throughout. Both halves are closed in **Phase 0c**
(L1, L2, `5ec4301`). The harness that went looking is built now (**G4**, `2afc200`), and its first
render found a third thing (**L3**, Phase 0d): the chart silently dropped doses over 150 mg — fixed at
`4fb39d9`, and the same render filed **L4** (two bedtime numbers, two dose sets — ruled 2026-10-17 and closed at `6a9d9de`) and **L5** ("Peak" named the first dose's peak, not the curve's — fixed at
`1683c6f`). The harness's own limit is gone too (**G5**, `fa60bfa`): the clock is one seam a render
pins, so a picture is a function of the instant asked for rather than of when it was drawn.

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
its commit. **Exit met: K1-K5 are ALL closed — K1 (2542390), K2 (bed737d),
K3 (f5a71d7), K4 (a6a9470), K5 (2aeb51d) — each with a red-first test.**
Size **M**, one session.

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

**K4. Bedtime residual tiers 25 / 50 / 100 mg: only 100 mg is sourced — DONE.**
`Sensitivity.safeCaffeineAtBedtime` and `CaffeineConstants.*BedtimeMg`.
koffee_big's audit found no source for the tiers (efsa2015sleep backs 100 mg).

**The tiers did not change, and that is the finding.** The obvious reading of
this item — "the threshold is 100 mg with its citation" — is to collapse all
three to 100. That is the wrong direction: it makes the app **laxer** for medium
and high readers, which is exactly what the standing rule forbids, the same rule
K1 broke when `multiplier * 400` showed a low-sensitivity user 480 mg/day as
safe. Warning earlier than the evidence requires is a preference; warning later
would be a claim. koffee_big kept 25/50/100 for the same reason, on 2026-09-08.

So the item is closed by making the distinction **visible**, not by moving the
numbers:

  * `safeCaffeineAtBedtime` carries its own sourcing docstring, including an
    explicit instruction not to collapse it, so the next reader does not have to
    re-derive the direction.
  * `bedtimeThresholdName` names each threshold for the reader — "the 100mg
    research limit" for the sourced one, "your stricter 50mg choice" for the
    convention — and the dashboard's over-limit sentence uses it. A convention
    that renders exactly like a finding is a finding, whatever the docstring
    says.

**The actual defect was the duplication, and it was dead.**
`CaffeineConstants` carried `high/medium/lowSensitivityBedtimeMg` at 25 / 50 /
100 — a verbatim restatement of `Sensitivity`'s switch with **zero call sites**.
The item named this ("two copies of the same three numbers") and it was right,
but the copy was not stale, it was inert: a dead copy of a safety number is one
edit away from being the live one, and nothing would announce the change. All
three are deleted, and `BedtimeThresholdProvenanceTests` refuses the declaration
returning.

Red first, and calibrated. Reintroducing the duplicate declaration fails the
scan; setting medium to 150 mg — laxer than the sourced figure — fails the
one-directional property *by name*, which is the assertion that stops a future
session from "tidying" K4 in the forbidden direction.

Two things the tests themselves cost, both recorded because each is a shape:
the scan first grepped for the bare symbol and went red on the *comment
explaining the removal* — matching the declaration keeps the repo able to record
why they are gone. And the source path was one `deleteLastPathComponent()`
short, which `try!` caught as a crash rather than letting the scan read nothing
and pass; both tests are now `throws`, which fails just as loudly and passes
the repo's `force_try` lint.

User-visible: the dashboard says "over your stricter 50mg choice" instead of
"over the 50mg limit". No threshold changes.

**K5. The interaction-extension model and its dead constants — DONE.**
`calculateCaffeineLevel(interactions:)` lengthened caffeine's half-life by
`extensionHours` — the theanine-extends-caffeine model the audit refuted
(theanine has no CYP1A2 effect; Grzegorzewski 2022). No caller passed it after
the coffee-only strip. It is **deleted, parameter and all.**

"Unused" understates it. An unused parameter is a **seam**: the next compound
added to the stack would find a hand-hold labelled "extension hours" and nothing
recording that the model behind it was wrong. An unused API is a decision the
codebase is still willing to make.

Deleted beside it — both enum **bodies**, not their members, because an empty
enum is the same mistake in a second form:

  * `MathConstants` — `halfLifeDecayFactor`, `recoveryPenalty`, `lTheanineRatio`
    (1.5, half of the very model refuted above), `deepSleepMinimumMinutes`,
    `sleepScoreThreshold`, `lowSleepScoreThreshold`.
  * `PKEngineeringConstants` — `michaelisConstantKm` 150 mg, `maxEliminationRateVmax`
    50 mg/h. Worse than unused: it asserts **saturable Michaelis-Menten
    elimination**, whose first-order regime needs concentrations several times a
    lethal dose. Nothing called it, but its existence was a claim that caffeine
    elimination saturates in the therapeutic range, which it does not.

**Red first, and calibrated.** `InteractionExtensionRefutedTests` went red on
all eight constant names and both parameter tokens, by name, before any
deletion. Planting the parameter back fails it; planting one constant back
fails it too.

**The scan is deliberately strict in one direction and loose in the other, and
the difference is the lesson.** The refuted model's identifier must be absent
from `Models.swift` **entirely, including in prose** — my own first draft of the
explanatory comment spelled the old signature out verbatim, compilable, and the
test correctly refused it. A comment that transcribes a rejected API is a
template for reinstating it. K4's dead-duplicate scan, by contrast, matches the
declaration pattern and permits prose, because there documenting the removal is
the whole point. **A dead constant is history; a refuted claim is a hazard.**

User-visible: nothing. There were no callers.

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

- **G4. The recurring user-POV screenshot rule has no harness — DONE (`2afc200`).**
  "User-POV screenshot at native pixels for every visual change" was a standing constraint with
  nothing behind it: the repo had no render path and no render target, so the only way to take one was
  to launch the app on top of the owner's live data. It is now one command, one surface, no window:

      KOFFEE_RENDER=<surface> KOFFEE_RENDER_OUT=out.png \
        .build/harness/Build/Products/Debug/Koffee.app/Contents/MacOS/Koffee

  The catalog is `dashboard` (the plan's first item at wake, the bedtime sentence, the bedtime HUD)
  and `notifications` (the dose-dependent cutoff line). The fixture is built in an **in-memory**
  database through the same repositories the app reads, so a render never opens the user's file; the
  process is also given a scratch store for the singleton (L2). The PNG is 2× the point size — native
  pixels — with the appearance pinned light, so a dark-mode Mac is not the variable.

  Three things made two renders of the dashboard differ, each found by the harness's own gate rather
  than by eye, and each closed: `BubbleGenerator`'s `Int.random` layout (seeded while rendering), the
  liquid's `TimelineView(.animation)` stepping the physics on every draw
  (`LiquidContainerConfiguration.animates` now stops the step rather than only pausing the schedule),
  and `.symbolEffect(.bounce, value:)` on the banner's icon, which a snapshot catches mid-bounce (the
  harness disables animations in the render's transaction). Two renders are now byte-identical, and
  that is checked, along with the catalog refusing a name it cannot draw and each picture holding more
  than a flat colour.

  **What it must never claim:** the animated liquid, and any picture whose content moves with the wall
  clock. That second half was true when it was written — every fixture pointed its doses *ahead* of the
  render instant, an empty tank, a level that drifted between two renders seconds apart — and **G5**
  closed it: the tank, the "Current Caffeine" stat and the curve's shape are stable artifacts now.

- **G5. One seam for the clock, so a render is a function of the instant it names — DONE (`fa60bfa`).**
  `DateHelper.now` was the door and exactly one call site used it; everything else called `Date()`. A
  render therefore drew whatever the wall clock said at that moment — which is why G4's fixtures all
  pointed away from "now", and why its own reproducibility test could only fail while two renders
  happened to land in the same 30-minute sample. `DateHelper.pinnedNow` is the seam (a `Mutex<Date?>`,
  because it is read from main-actor views *and* from GRDB's write queue), and `nil` is the app: the real
  clock, every routed site byte-for-byte what it was. `RenderHarness.render(_:at:)` freezes it for one
  draw and restores what it found, so a render cannot leak into the app or into the next test.

  Two sites keep the wall clock, and the lock names them: the harness's `settle` waits in *real* time for
  SwiftUI to lay out (a deadline of "the pinned instant plus 0.4 s" would return immediately for a
  fixture dated in the past), and the process log's timestamp says when a line was written rather than
  what the app thinks today is. The lock itself is `WallClockDoorTests`: it walks `Koffee/`, skips
  comments, and fails on any `Date()` or `Date.now` outside the allowlist — and **an entry that has gone
  stale fails too**, so the list cannot rot into a description of code that no longer exists. Calibrated
  in both directions: a planted `Date()` in `FocusWindow.swift` was listed by file and line, and an
  allowance of 4 where only 3 exist was reported stale.

  The harness pins **noon** on the fixture's day — the hour the existing exhibits were drawn and verified
  at — and `KOFFEE_RENDER_AT=HH:MM` moves it, so "draw the evening state" is a command rather than an
  edit. A value that is not a time is refused (`BadInstant`: exit 1, no PNG) the way an unknown surface
  is. Evidence, two separate processes each: default renders byte-identical (`cmp`), 16:00 ≠ noon, and
  the difference is exactly the clock-driven elements — `Current Caffeine` 47 mg → 201 mg, the ring's arc,
  the tank's bubble count, "Peak At 15:00" → "Peak 15:00" — while the curve and the bedtime projection
  are unchanged. The owner's live database is untouched through all of it (`Oct 16 10:26:47`).

  What it does not do: the fixture's doses are fixed times on its day, so the pin chooses *which of them*
  is already in the tank, rather than expressing a state the fixture cannot build. And the tank's level
  still comes from logged doses alone while the chart draws logged doses *plus* pending plan items — the
  L4 question, then visible in a third surface: at noon `currentCaffeineLevel` was 0 beside a
  "Current Caffeine" of 47 mg. Closed by L4 (`6a9d9de`): the tank reads the same ruled dose set.

- **G6. Nothing checked the architectures the app ships — DONE.**
  The Release build was arm64-only because `project.yml` said `ARCHS: "arm64"`, and nothing failed
  if an x86_64 slice came back: a setting that is only a setting is a convention, and the house
  rule (target-platform-policy) is that an unsupported architecture is a HARD FAILURE, never a
  warning that builds anyway.

  `tools/arch_gate.sh` reads the supported set from **one** declared source — `project.yml`'s
  `ARCHS` — builds Release, reads the shipped Mach-O with `lipo -archs`, and fails if any
  architecture outside the declared set is in it (an embedded framework counts: it ships too).
  It fails closed: no binary, no declared `ARCHS`, an unreadable project file are all red, never
  a pass because the checker could not read its subject. A second copy of the set inside the
  script would be a second policy, and a policy that can disagree with the build is not one.

  `tools/arch_gate_test.sh` is the calibration: it builds real Mach-O fixtures (the declared
  architecture, an undeclared one, and a universal binary carrying the slice that came back) and
  reads every red by its MESSAGE, not only by its exit code. Both run in `tools/gate.sh --full`,
  after the swift gate — that gate wipes `.build` when it is cold, so a Release build made
  before it would be deleted before it could be read.

  Red before green: the planted universal Release binary read `arm64 x86_64` and the gate named
  `x86_64`; the real product reads `arm64`.

## Phase 0c — the launch path and the user's data (found 2026-10-16)

Found while probing a headless render harness, which needs the test process to stop touching the
live database. One cause behind both halves: `Koffee/App/main.swift`'s
`applicationDidFinishLaunching` runs on **every launch**, and it is also the **test host**
(`project.yml` sets `TEST_HOST` to `Koffee.app`), so whatever it does at launch happens on every
`xcodebuild test` too — including the one the push gate runs.

**L1. Every launch deletes and recreates the user's profile. — DONE (`5ec4301`).**
`main.swift` calls `UserProfileModel.deleteAll(db)` and then writes a fresh
`UserProfileModel(wakeTime: today 07:00, sleepTime: today 23:00, …)`, so wake time, sleep time,
sensitivity, metabolism, weight and stack compounds are **reset to defaults on every launch**.
Measured, not read: a single existing test run
(`-only-testing:KoffeeTests/AppStateTests/testAddDoseThroughAppState`) moved a live profile's
`wake_time` from `2026-10-15 11:00` to `2026-10-16 11:00` and `updated_at` to the second the run
started. Note the shape: the dates are *today's* defaults, which is the tell that this is the daily
roll, not a one-off reset.

The delete is load-bearing for that roll — the profile stores wake/sleep as absolute datetimes and
`refreshDailyPlan` schedules the first item AT `wakeTime`, so the row's dates have to be today's —
which is why the fix is a ROLL and not a removal: transpose wake/sleep onto today and keep every
setting the user chose. `HistoryView` already did exactly this roll with
`transposedWallTime(from:onto:calendar:)`, which is now shared rather than copied. The shape was
ruled: **roll the stored dates** (the alternative, storing the times as wall-clock times and
deriving today's dates at read time, is cleaner but reaches plan scheduling, the chart, history and
notifications, and was not taken for a defect this size). The row keeps its id, its settings and its
`updated_at`; only the two dates move, and `ProfileDayRoll.store(in:day:)` is the step `main.swift`
calls — the same read, roll and save a test drives against a real database.

**L2. The gate's test run reads and writes the live database. — DONE (`5ec4301`).**
Because the host is the app, `DatabaseManager.shared.open()` opens the real file, and the suite
reaches it through `AppState+DailyPlan`'s `dbWrite` (the stale-plan-item delete) and
`BeverageManager` — so a push can write to the user's database, and every test that calls
`refreshDailyPlan()` depends on the live file being open rather than on the store it was handed.
Fix at the one singleton: under `XCTestConfigurationFilePath`, `DatabaseManager.dbURL` is a
per-process scratch file, so the suite gets its own store and the user's file is never opened. This
is the harness's precondition, not a preference: a render harness runs in this same process.

## Phase 0d — found by the first render (2026-10-16)

The harness's first screenshot (G4) put two bedtime numbers on one screen. Three defects sat
behind that disagreement; all three are closed below (L3, L4, L5).

**L3. The chart drops every dose over 150 mg. — DONE (`4fb39d9`).**
`generateUnifiedCurvePoints` (`Koffee/Data/Models.swift:171`) ran
`doses.filter { _, mg in mg <= 150 }`, directly under a comment that promises "Chart what the caller
passed - no wall-clock filtering here". No wall-clock filtering did happen — but a magnitude filter
did, so every dose above 150 mg was missing from the curve **and from the three stats the chart reads
off that curve**: `Current Caffeine`, `At Bedtime` and `Peak` in `UnifiedChartView`'s status row.

Evidence, from one render of the `dashboard` surface before the fix: the fixture logs 200 mg at 15:00
and plans 95 mg at wake. The app's own trace printed `caffeine for calc: 1/2`; the curve's stat row
read **"At Bedtime 10mg"** (the 95 mg plan item alone) while the banner read **"Put the pot down —
65mg at bedtime"**, projecting from `appState.todayDoses` through `projectBedtimeCaffeine`. Same
screen, same instant, two answers.

Why the limit existed is no longer a mystery, and `git log -S` answers it: it arrived with `bd2134d`
"Strip non-coffee features: coffee/caffeine-only app" (2026-09-08), where a magnitude ceiling stood in
for "this is a caffeine dose, not L-theanine or magnesium" — the tuple the chart is handed carries no
compound, so a magnitude proxy was what there was. The app is caffeine-only now, so the proxy has no
reason left and the filter is pure loss: the fix **deleted** it rather than porting it to a compound
check (`DoseRepository.add` writes `compoundUuid == nil` for every normally logged dose, so a compound
filter would drop all of them — which is likely why nobody wrote one).

Red first, `CurveDoseMagnitudeTests`: a 200 mg dose must reach the curve at its taken size (read
`0.0`), and the curve's bedtime value must equal `projectBedtimeCaffeine`'s on the same dose (read
`0.0` against `65.98`). After: the dose is drawn — the curve steps 27 → 200 at 15:00 and the axis
rescales to 200 — and the `caffeine for calc` trace is gone.

**The sentence this item used to carry was wrong, and the render is how it was caught.** It said "set
the same 200 mg dose below 150 and the two agree". The post-fix render refutes it: the stat row reads
**"At Bedtime 76mg"** against the banner's 65mg, and 76 = 65 + 10, the pending plan item. The filter
was one cause; the dose set is another.

**L4. Two bedtime numbers, two dose sets. — DONE (`6a9d9de`).**
Owner ruling (2026-10-17): the dose set is **planned + logged**, deduplicating
the case where the planned dose was already logged. The dedup is structural: a
taken plan-dose is logged with the plan item's own id
(`addWithId(id: item.id)`), so dose id == plan item id is one cup, not two.
New pure derivation `effectiveDoseSet(loggedDoses:pendingPlanItems:)` in
`Koffee/Data/DoseSet.swift` is the one set every surface reads:
- `AppState.updateCaffeineLevels` (tank + its bedtime field)
- `DashboardView.updateCaffeineLevel` (banner)
- `DashboardView.compositeDoses` (the curve)
- `DashboardView.activeStimulantLoad`
- `projectedBedtimeCaffeine(byAdding:)` (beverage preview)
- `CaffeineTimelineChart.bedtimeCaffeineLevel` (stat row — new exposed value;
  the row now calls the funnel, not a curve read, so banner and stat row agree)

Bug found and fixed along the way: `DoseModel.didInsert` overwrote the custom
id with the rowID, breaking the structural link the dedup relies on. Fixed to
only overwrite auto-generated UUIDs. Also `DoseRepository.add`/`addWithId`/
`delete` now call `reload()` so read-after-write is synchronous (GRDB's
`.immediate` scheduler is async for subsequent observations).

Proof: `EffectiveDoseSetTests` (7 tests) — watched red first (compile error:
helper and chart property didn't exist); full suite 226/226 green.

**A third surface turned up with the clock pin (G5).** `AppState.currentCaffeineLevel` — the tank, and
the level the dashboard's ring draws — is computed from `self.doses` filtered to today, logged only, so
at the noon pin it reads **0** while the chart's stat row reads **47mg**. It is the same ruling: whichever
set is correct has to be the set the tank, the chart's stat row and the banner all read.

**L5. "Peak" is the first dose's peak, not the curve's. — DONE (`1683c6f`).**
`UnifiedChartView.swift:195` computed `peakTime = doses.first?.time + 45min`, so the label named when
the *earliest* dose peaks — approximately right only while the first dose of the day dominates. The
other two stats on that row (`Current Caffeine`, `At Bedtime`) are read off `chartData`; the peak was
the only one read off the input doses with a hand-rolled offset. L3 is what made it visible: before it
the drawn curve's maximum was at 07:00 and the label said 07:45; after it the curve's maximum is at
15:00 and the label still said **"Peak 07:45"**, printed beside it.

Red first, `ChartPeakLabelTests`, which asserts the view's own value rather than scanning the source
(the view is constructible from the test target): with the old body the row named 07:45 where the
curve peaks at 15:00, and 09:45 where a single 09:00 dose peaks. Red was re-confirmed after the class
needed `@MainActor` (D-0016 — fixed, not silenced). `peakInstant` is now the curve's high point, and
nil rather than `Date()` when there are no doses. Measured after, on the `dashboard` render:
**"Peak At 15:00"** sits under the spike that used to be labelled "Peak 07:45"; the other two stat
values are unchanged.

Two things this deliberately did not settle:

- The 45-minute absorption allowance is **gone from the label** rather than moved onto a different
  dose. The model has no absorption term for it to describe — `calculateCaffeineLevel` is pure decay,
  so the curve the label annotates peaks at the dose instant — and a derived value cannot drift from
  the picture it sits under. Give the model absorption (`K1`-style, a phase-2 question) and the label
  follows it automatically. Two leftovers now carry the concept instead: `calculateOptimalFocusWindow`
  has its own **+1h** peak allowance (for the first dose's window, so not L5), and
  `NootropicCompound.peakTimeMinutes` (= 45) is referenced by nothing, and already was before this
  change — a dead descriptor of the compound era, like `safeLimitMg` in the same enum.
- `isPeakPast` reads `Date()` directly, so the "Peak" / "Peak At" choice is wall-clock dependent at the
  peak instant. That is the same class as `Current Caffeine` reading a curve sample against `Date()`,
  and both are what the clock seam (named in G4's limits, above) is for.

## Phase 2 — product (only after Phase 0b)

The 2026-09-08 loop goal ("make this the best coffee intake app in history")
is carried as these concrete items, in koffee_big's competitor-survey order:
every top-rated caffeine app has a caffeine-free-at forecast, a bedtime-level
forecast and quick-log. Size **M** each.

- **P1. "Caffeine-free at" and bedtime forecast** on the dashboard, computed
  through `projectBedtimeCaffeine` (the one funnel) with K3's per-dose cutoff — **DONE.**
  The bedtime forecast was already on the dashboard (the HUD's `BEDTIME` widget and the
  oracle sentence, both the funnel's number); the missing half was the caffeine-free
  time, and it is now a third line of the oracle card.

  `CaffeinePK.caffeineFreeAt` SOLVES for the instant the day's modelled caffeine reaches
  the threshold the app reports as nothing — **1 mg, the app's own reporting resolution**
  (the dashboard prints whole milligrams). The line the sentence names is the line the
  derivation uses, so "caffeine-free" is not a claim the reader has no way to check: the
  copy says "under 1mg". The level is read from `calculateCaffeineLevel`, so the forecast
  and the drawn curve are one decay and one dose set (L4) — a forecast that disagreed with
  the chart would be the two-numbers-one-screen defect again.

  The DAY is named with the time ("today", "tomorrow", or the date): a clock time without
  its day is a forecast the reader has to guess about. The instant is the crossing, so a
  reader already under the line is told "now" rather than a time in the past.

  Red first, and calibrated in both directions: dropping the metabolism multiplier and
  adding an hour of slack each turned the suite red by name (the level at the named
  instant read 0.87 mg, not 1 mg). 236/236 green.

- **P2. Quick-log from the menu bar / a widget** for the usual beverage
  (`usualBeverageId` exists).
- **P3. Tolerance as a pharmacodynamic gain, not a clearance change** — only if
  a tolerance input is added; chronic use does not change half-life (Robertson
  1981, Shi 1993). Parked until a user-facing reason exists.

## Releases — how this repo ships

There is no CI and no distribution channel: the pre-push gate (`tools/gate.sh --full` on a clean
export of the pushed commit) is the CI, and the user's machine is the only install.

1. Bump `MARKETING_VERSION` (and `CURRENT_PROJECT_VERSION`) in `project.yml` — the ONE version
   source; `.gatesrc` declares it (`GOH_TAG_VERSION_SOURCES=xcodegen:project.yml`), so the pre-push
   refuses a `v<semver>` tag the bundle would not report.
2. `tools/gate.sh --full` green; build Release, replace `/Applications/Koffee.app`, confirm
   `CFBundleShortVersionString` is the new version and the app launches.
3. `git tag -a vX.Y.Z` with the notes (what changed, what was wrong, what to re-check), then ONE push:
   `git push origin main vX.Y.Z`; prove it with `git fetch`, `rev-list --count origin/main..main` = 0
   and the tag in `git ls-remote --tags origin`.

## Recurring gates (run them every pass)

- Greyscale single-channel check on every new visual distinction.
- User-POV screenshot at native pixels for every visual change — now one command per surface
  (`KOFFEE_RENDER=dashboard|notifications`, see G4), not a launch over the owner's data.
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
