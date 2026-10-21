# Changelog

Koffee's release notes live in the annotated git tags (`v0.1.0`, `v0.2.0`); this file is the
running list, newest first, so a reader does not have to read a tag's prose to learn what a
commit changed.

## Unreleased

**The plan is pruned to what is open.** `ROADMAP.md` is the one forward-looking
file, and the closed rows (Phase 0b's K1-K5, Phase 0c's L1-L2, Phase 0d's
L3-L5, Phase 1's G1-G7, Phase 2's P1) have left it. What each was, and why it
was right, is in `git log` and in the version of the plan before the prune
(`git show 0b835c9:ROADMAP.md`); the commits that shipped them are named in
the plan's state block, so nothing is lost and no closed item reads as work
that is still to do.

- What is left: **P2** (quick-log — the owner chooses the surface) and **P3**
  (tolerance — parked until a user-facing reason exists), plus the house rows
  7.4 (where the "no tracked build output" check runs) and 3.3 (no subject
  here: this repo tracks no Python).

What a user sees: nothing. What a reader sees: a plan that says what is open
and who can move it.

**The greyscale check has a harness.** "Greyscale single-channel check on every new visual
distinction" was a standing rule with nothing behind it: the check ran in nobody's head, so a
distinction that failed in greyscale passed the gate silently. It is now one command, wired into
the pre-push gate, and it fails with the reason.

- The states are DISCOVERED in the sources — an if/else chain, a switch, a ternary chain — not
  read from a list. A hand-kept list goes stale, and a stale list is a gate that checks the wrong
  thing; a distinction added tomorrow is found tomorrow.
- The colours are MEASURED through AppKit in the light and the dark appearance, and turned into
  the greyscale the reader actually sees (CIE L*). A table of remembered RGB values is a table that
  rots, and a check built on a rotted table cannot fail.
- The rule: a distinction carried by colour alone — no word, no symbol, no shape, and no other
  group in the same file that already tells the states apart — whose colours are closer than
  10 L* apart is refused, named by file, by the two states, by their colours and by the gap.
- `tools/greyscale_gate_test.sh` is the calibration: it plants a distinction that fails in
  greyscale (the chart's over-limit figure repainted orange, which is the same shade as green)
  and reads the verdict by its MESSAGE, not only by its exit code.
- The checker's first run refused `colorForCompound(_:)` — thirteen compounds, thirteen colours,
  no name beside them, and no caller left. It is deleted.

What a user sees: nothing. What a push sees: a tree whose new visual distinction rides on hue
alone is refused.

Re-check on your own setup: `tools/greyscale_gate.sh` prints the distinctions it found and the
closest pair it judged; `tools/greyscale_gate_test.sh` proves the check can still fail.

**The dashboard is split along its seams.** `DashboardView.swift` was 483 lines against a
500-line cap, so the next addition there would have tripped the gate the plan set on purpose. The
cap is a ceiling to force a split, not a number to raise, so the file is split instead.

- `DashboardOracleBanner.swift` — the banner, a view that takes what it shows and derives
  nothing.
- `DashboardCopy.swift` — the oracle's sentences, as pure functions.
- `DashboardWidgets.swift` — the stat tiles.
- `DashboardBubbles.swift` — the bubble layout helpers.

What a user sees: nothing. The dashboard draws the same pixels; 236 tests and the full gate are
green. `DashboardView.swift` is 271 lines, with room to work.

Re-check on your own setup: nothing to re-check — this is a move, and the gate is the proof.

**The shipped architectures are gated.** The Release build was arm64-only because `project.yml`
said `ARCHS: "arm64"`, and nothing failed if an x86_64 slice came back — a setting that is only
a setting is a convention, and the house rule (target-platform-policy) is that an unsupported
architecture is a HARD FAILURE, never a warning that builds anyway.

- `tools/arch_gate.sh` reads the supported set from ONE declared source (`project.yml`'s
  `ARCHS`), builds Release, reads the shipped Mach-O with `lipo -archs`, and fails if any
  architecture outside the declared set is in the binary — an embedded framework counts, it
  ships too. It fails closed: no binary, no declared `ARCHS`, an unreadable project file are
  all red.
- `tools/arch_gate_test.sh` is the calibration: it builds real Mach-O fixtures (the declared
  architecture, an undeclared one, and a universal binary carrying the slice that came back) and
  reads every red by its message, not only by its exit code.
- Both run in `tools/gate.sh --full`, after the swift gate — that gate wipes `.build` when it
  is cold, so a Release build made before it would be deleted before it could be read.

What a user sees: nothing. What a push sees: a tree that ships an x86_64 slice is refused.

Re-check on your own setup: `tools/arch_gate.sh` prints the declared set and the architectures of
the Release binary it built; `tools/arch_gate_test.sh` proves the check can still fail.

**The dashboard forecasts when you are caffeine-free (P1).** The banner now carries a third line
under its advice: "Caffeine-free at 06:16 Wed 21 Oct (under 1mg)."

- The instant is solved from the day's modelled caffeine, read from the same decay model the
  chart draws and over the same ruled dose set (planned + logged, deduplicated) — so the
  forecast and the curve are one number, not two.
- "Caffeine-free" is only ever true of a line the app chose, so the line is named: **1 mg is
  the app's own reporting resolution** (the dashboard prints whole milligrams), and the
  sentence says "under 1mg".
- The day is named with the time ("today", "tomorrow", or the date), because a clock time
  without its day is a forecast the reader has to guess about. A reader already under the
  line is told "now", not a time in the past.

What a user sees: one more line in the dashboard banner. What changed underneath: a solved
derivation (`CaffeinePK.caffeineFreeAt`) and 10 tests that were red before they were green.

Re-check on your own setup: open the dashboard after a coffee — the line names the instant the
level reaches 1 mg, and the day it falls on.
