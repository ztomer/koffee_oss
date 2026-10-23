# Koffee Roadmap

The one forward-looking plan for this repo. Shipped work lives in `git log`;
the version of this file before the 2026-10-21 prune is
`git show 0b835c9:ROADMAP.md`, and the one before that
`git show 7cf37e8:ROADMAP.md`.

## What this repo is, and how it relates to koffee_big

Koffee is the **open-source, coffee-only** caffeine tracker for macOS (SwiftUI +
GRDB). It is a FORK of koffee_big's early history (the `koffee-big-ancestor`
remote points at `ztomer/Koffee_big`), flattened to one commit on 2026-09-04 and
stripped to caffeine on 2026-09-08 (`bd2134d`). koffee_big has since become a
different product (BigKoff: cognitive capacity, supplements, an Android
companion, a portable engine). Nothing merges between them in either direction.

The consequence that matters: **this fork was cut BEFORE koffee_big's
2026-09-08 evidence audit**, so it shipped the caffeine numbers that audit
proved wrong — and Phase 0b has since corrected every one of them (K1-K5,
closed 2026-10-15). koffee_big's `FEATURE_PLAN.md` evidence archive ("SOTA
evidence program") is the reference for every Phase 0b item; port the corrected
NUMBERS and their citations, never BigKoff's code.

Standing constraints: everything data-driven, nothing hardcoded (derive from
`beverages.json`, GRDB, or computed PK values). House gates stay green: build,
236 tests, `swiftlint --strict`, no compiler warnings, user-POV screenshot for
every visual change, greyscale check for every new distinction, and a new test
must go red once before it is trusted green.

**State (measured 2026-10-21):** v0.2.0 released (Phase 0b, 0c, 0d — the tag
points at `a83bfcd`); `main` is in sync with `origin/main` at `0b835c9`.
`tools/gate.sh --full` is **green** (re-run 2026-10-21 on `0b835c9`: the
structural layer, the swift gate with `swiftlint --strict` and the coverage
floor, the arch gate, the greyscale gate and the no-bare-print gate).

**What has landed, and where its record is.** Phases 0b, 0c, 0d and 1 are
CLOSED: their rows are gone from this file — this plan is forward-looking, and
the narrative is in `git log` and in `CHANGELOG.md`. What remains here is one
line per item and the commit that shipped it:

- Phase 0b — K1 `2542390`, K2 `bed737d`, K3 `f5a71d7`, K4 `a6a9470`, K5 `2aeb51d`
- Phase 0c — L1 and L2 `5ec4301`
- Phase 0d — L3 `4fb39d9`, L4 `6a9d9de`, L5 `1683c6f`
- Phase 1 — G1, G2 and G3 `e154e5a`; G4 `2afc200`; G5 `fa60bfa`; G6 `56b174b`
  (arm64 only: `a83bfcd`); G7 `d48a58a`
- Phase 2 — P1 `e4296ff`

Two of them were found by the first render on 2026-10-16: the launch path
deleted and recreated the user's profile on every launch (and because the test
host is the app, a push did it too — `tools/gate.sh --full` was green over it
throughout), and the chart silently dropped every dose over 150 mg.

## Phase 0 — wire in goh 0.27.0: closed 2026-10-14

`tools/gate.sh --full` green at `6129495`, pushed (pre-push 46 s).

- **W.1** `no early-exit pipe under pipefail` (11 sites; five unused scripts deleted, no seed): `1ef235c`
- **W.2** `--full` runs `xcodegen generate` before the swift gate, green in a fresh worktree: `4f948c4`
- **W.3** Scanner floors (11 keys, calibrated red): `6129495`
- **W.4** `main` tracks `origin/main`; pushed: `6129495`

## Phase 0b — the shipped pharmacology that has no support (core rule 8): closed 2026-10-15

Goal: no number or advice Koffee shows contradicts the evidence. Correctness
outranks keeping a number stable; state each user-visible change's magnitude in
its commit. **Exit met: K1-K5 are ALL closed**, each with a red-first test.
Size **M**, one session. The rows are gone from this file; the narrative is in
`git log` and in the version of this file before the prune
(`git show 0b835c9:ROADMAP.md`), and the shipped numbers are in
`CHANGELOG.md`.

- **K1** the daily ceiling exceeded 400 mg for "low sensitivity" — `2542390`
- **K2** the "first coffee 90 min after waking" advice had no trial behind it — `bed737d`
- **K3** the fixed cutoff hours 6 / 9 / 12 by sensitivity were unsourced — `f5a71d7`
- **K4** the bedtime residual tiers 25 / 50 / 100 mg: only 100 mg is sourced — `a6a9470`
- **K5** the interaction-extension model and its dead constants — `2aeb51d`

## Phase 1 — gate holes: closed 2026-10-20

Goal: the gate can fail on everything the house rules require. Size **S**. The
rows are gone from this file; the narrative is in `git log` and in the version
of this file before the prune (`git show 0b835c9:ROADMAP.md`), and the two
landings a user can see are in `CHANGELOG.md`.

- **G1** no coverage floor — `e154e5a`. `GOH_SWIFT_COV_MIN=40` in `.gatesrc`,
  with per-target floors in `tools/coverage_floors.jsonc`: the whole-tree
  number is meaningless here, because AppAuth, GRDB, KeychainAccess and
  LiquidContainer are third-party and report 0%. Setting the floor needed goh
  v0.28.1's `xccov` reader (`b267e82`) — before it, the xcode path could not
  be measured at all, so the floor had been unset because it was unsettable,
  not because the decision was deferred.
- **G2** Xcode build logs were tracked — `e154e5a`. The six tracked files are
  zero (`git rm -r --cached DerivedDataTests`), and the path is in
  `.gitignore` with a note saying why. **The house row for this repo is
  `gates_of_heck`'s BACKLOG 7.4, and what is left in it is the OWNER's
  decision:** the check itself landed at goh v0.44.0 (`854c675`), and 7.4 now
  asks where it RUNS — either every consumer adopts it in its own gate, or it
  becomes a structural step with `old_phones`' seed file, which is a write in
  another repo and therefore the owner's to make. This repo tracks no build
  output either way (re-measured 2026-10-21: `git ls-files` lists no
  `DerivedData` path).
- **G3** seven bare `print(` calls in `Koffee/` — `e154e5a`. They go through
  `debugLog()`, and `tools/no_bare_print.sh` gates them.
- **G4** the recurring user-POV screenshot rule had no harness — `2afc200`.
  `KOFFEE_RENDER=<surface> KOFFEE_RENDER_OUT=out.png` renders one surface to a
  native-pixel PNG, from an in-memory fixture, with no window on the display.
- **G5** one seam for the clock, so a render is a function of the instant it
  names — `fa60bfa`. `DateHelper.pinnedNow` is the door; `WallClockDoorTests`
  refuses any other read, and an allowance that has gone stale fails too.
- **G6** nothing checked the architectures the app ships — `56b174b` (arm64
  only: `a83bfcd`). `tools/arch_gate.sh` reads the declared set from one
  source (`project.yml`'s `ARCHS`) and fails if any other architecture is in
  the shipped binary; it fails closed.
- **G7** the recurring greyscale rule had no harness — `d48a58a`.
  `tools/greyscale_gate.sh` finds the distinctions in the sources and measures
  their colours, so a distinction carried by colour alone is refused, named by
  file, by the two states and by the measured gap. The measured margin today
  is 12.5 L\* (yellow against green, the history view's risk colours).

## Phase 0c — the launch path and the user's data (found 2026-10-16): closed 2026-10-16

One cause behind both halves: `Koffee/App/main.swift`'s
`applicationDidFinishLaunching` runs on **every launch**, and it is also the
**test host** (`project.yml` sets `TEST_HOST` to `Koffee.app`), so whatever it
does at launch happens on every `xcodebuild test` too — including the one the
push gate runs. The rows are gone from this file; the narrative is in `git log`
(`a009655` recorded the closure).

- **L1** every launch deleted and recreated the user's profile — `5ec4301`.
  The fix is a ROLL: the stored dates transpose onto today and every setting
  the user chose is kept.
- **L2** the gate's test run read and wrote the live database — `5ec4301`.
  Under `XCTestConfigurationFilePath` the suite gets its own scratch store, so
  the user's file is never opened.

## Phase 0d — found by the first render (2026-10-16): closed 2026-10-17

The harness's first screenshot (G4) put two bedtime numbers on one screen.
Three defects sat behind that disagreement; the rows are gone from this file
and the narrative is in `git log` (`c005ca4` and `a13343d` recorded them).

- **L3** the chart dropped every dose over 150 mg — `4fb39d9`. The magnitude
  filter was a compound proxy left by the 2026-09-08 strip; the app is
  caffeine-only now, so the fix deleted it.
- **L4** two bedtime numbers, two dose sets — `6a9d9de`. Owner ruling
  (2026-10-17): the dose set is **planned + logged**, deduplicated on the
  plan item's own id, and one derivation that every surface reads.
- **L5** "Peak" named the first dose's peak, not the curve's — `1683c6f`.

## Phase 2 — product (only after Phase 0b)

The 2026-09-08 loop goal ("make this the best coffee intake app in history")
is carried as these concrete items, in koffee_big's competitor-survey order:
every top-rated caffeine app has a caffeine-free-at forecast, a bedtime-level
forecast and quick-log. Size **M** each. This is the PRODUCT phase, and one
item in it waits on the OWNER.

- **P1. "Caffeine-free at" and bedtime forecast** on the dashboard — **closed
  (`e4296ff`)**: the forecast solves for the instant the day's modelled
  caffeine reaches the threshold the app reports as nothing (1 mg, the app's
  own reporting resolution), and the copy names the line it solved for. The
  narrative is in `CHANGELOG.md`.
- **P2. Quick-log from the menu bar / a widget** for the usual beverage
  (`usualBeverageId` exists) — **closed (2026-10-23)**: the owner ruled the menu
  bar (`p2 - menubar`). Menu bar popover displays live active caffeine level,
  risk badge, prominent quick-log for the usual beverage (or default coffee),
  menu for alternate beverages, and window reveal action. Bound reactively to
  `AppState`, added to `RenderHarness` (`.menubar`), and covered by `MenuBarManagerTests`.
- **P3. Tolerance as a pharmacodynamic gain, not a clearance change** —
  **parked**, and it stays parked until a user-facing reason exists: a
  tolerance INPUT is added, and then chronic use is modelled as a gain, never
  as a clearance change (chronic use does not change half-life — Robertson
  1981, Shi 1993).

---

## Open, and who can move it

What is open in this repo, and the hand each one needs. Every other item in
this file is closed, and the commit that shipped it is named above.

- **P2, quick-log** — **closed (2026-10-23)**: menu bar quick-log for the usual beverage
  shipped with live AppState binding, alternate beverage menu, and tests.
- **P3, tolerance** — **parked**: it starts when a tolerance input is added,
  and it is not agent work before that.
- **The house's 7.4, the "no tracked build output" check** — **the owner**:
  the check has landed in `gates_of_heck`; what is left is whether it runs in
  each consumer's own gate or becomes a structural step, and the second option
  is a write in another repo.
- **The house's 3.3, the estate stdin sweep** — **nothing to do here**: this
  repo tracks no Python, so the sweep reads no subject and exits 0
  (re-read 2026-10-21: "not applicable — this repo tracks no Python source").

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

- Greyscale single-channel check on every new visual distinction — now one command
  (`tools/greyscale_gate.sh`), and the states are found in the sources rather than kept in a
  list, so a new distinction is checked when it is added (see G7).
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
  Python, so the stdin gate reads nothing here: the house's 3.3 sweep has no
  subject in this repo, and `goh subprocess-stdin` exits 0 with "not applicable
  -- this repo tracks no Python source" (re-read 2026-10-21). The house row
  that IS open for this repo is 7.4 (Phase 1, G2), and it is the owner's
  decision.