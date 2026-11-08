# Koffee Roadmap

The one forward-looking plan for this repo: open work and the rulings still in
force. Finished work lives in `git log` and `CHANGELOG.md`; the plan before the
2026-11-08 rework is `git show bb4f686:ROADMAP.md`.

Koffee is the open-source, coffee-only caffeine tracker for macOS (SwiftUI +
GRDB), a fork of koffee_big's early history (stripped to caffeine on
2026-09-08, `bd2134d`). Nothing merges between the two in either direction.
State (2026-11-08): `main` is level with `origin/main`; the last release is
v0.2.0.

## Rulings in force

- **Correctness outranks a stable number** (core rule 8, 2026-08-15). A
  user-visible number that the evidence contradicts is corrected, and the commit
  states the magnitude. koffee_big's `FEATURE_PLAN.md` evidence archive is the
  reference: port corrected NUMBERS and citations, never BigKoff's code
  (this file, 2026-09-08 fork audit).
- **The dose set is planned + logged**, deduplicated on the plan item's own id,
  and one derivation that every surface reads (owner, 2026-10-17, commit `6a9d9de`).
- **Everything data-driven, nothing hardcoded**: derive from `beverages.json`,
  GRDB, or computed PK values (standing constraint of this repo).
- **arm64 only** (2026-10-19, `a83bfcd`): `tools/arch_gate.sh` reads `ARCHS`
  from `project.yml` and fails if any other architecture is in the binary.
- **No tracked build output** is a structural step of the house gate in every
  repo (owner ruling OW.29, 2026-10-31, `gates_of_heck` docs/BACKLOG.md 7.4);
  nothing is left to decide here.
- **Chronic use does not change half-life** (Robertson 1981, Shi 1993): any
  tolerance model is a pharmacodynamic gain, never a clearance change.
- **No CI and no distribution channel**: the pre-push gate
  (`tools/gate.sh --full` on a clean export of the pushed commit) is the CI.
- **Every pass**: a greyscale check for every new visual distinction
  (`tools/greyscale_gate.sh`), a native-pixel screenshot for every visual change
  (`KOFFEE_RENDER=<surface> KOFFEE_RENDER_OUT=out.png`), and a new test goes red
  once before it is trusted green.

## Release path

1. Bump `MARKETING_VERSION` (and `CURRENT_PROJECT_VERSION`) in `project.yml`,
   the ONE version source (`.gatesrc` declares it, so the pre-push refuses a
   `v<semver>` tag the bundle would not report).
2. `tools/gate.sh --full` green; build Release, replace `/Applications/Koffee.app`,
   confirm `CFBundleShortVersionString` is the new version and the app launches.
3. `git tag -a vX.Y.Z` with the notes (what changed, what was wrong, what to
   re-check), then ONE push: `git push origin main vX.Y.Z`; prove it with
   `git fetch`, `rev-list --count origin/main..main` = 0 and the tag in
   `git ls-remote --tags origin`.

## Phase 1 - parked product work (the only open item)

Why: every correctness, gate and product item through quick-log is finished,
so the one thing left is gated on an owner decision, not on dependencies.

- **P3. Tolerance as a pharmacodynamic gain, not a clearance change.** Parked
  until a user-facing reason exists; it starts when a tolerance INPUT is added
  to the profile, and it is not agent work before that. Today only a
  consecutive-days alert exists (`toleranceAlert` in `Koffee/Data/AppState.swift`);
  there is no tolerance input and no gain model.
  Done when: (owner to decide). What would prove it: a tolerance input in the
  profile, and a red-first test showing that the same dose history changes the
  modelled effect while the half-life and clearance the model reports stay
  identical.
