#!/usr/bin/env bash
# Per-repo gate entry point. Declares which toolchains this repo contains and
# delegates; it holds no gate logic of its own.
#   --staged : pre-commit scope (fast) — layer 1 only
#   --full   : pre-push scope — every layer
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GOH="${GOH_DIR:-${GOH:-$HOME/Projects/gates_of_heck}}"

"$GOH/gates/structural.sh" "$@"

case "${1:-}" in
  --full)
    # Per-language layers for what this repo actually contains:
    #
    # swift: Koffee app (xcodebuild) + LiquidContainer SPM package.
    #   Lint debt cleared 2026-08 - swiftlint --strict is green.
    #   Coverage floor set 2026-10-15 (G1): GOH_SWIFT_COV_MIN=40 with per-target
    #   floors in tools/coverage_floors.jsonc -- measured, and aimed at the app.
    # Koffee.xcodeproj is xcodegen output and gitignored, so the clean export
    # of the pushed commit that the pre-push gate tests has none. Generate it
    # from project.yml on every run, never carry one in (GOH_EXPORT_KEEP would
    # test a stale project against fresh sources).
    command -v xcodegen >/dev/null || {
      echo "✗ xcodegen not found: the gate generates Koffee.xcodeproj (brew install xcodegen)" >&2
      exit 2
    }
    xcodegen generate --quiet
    # Before the swift gate, so a planted print is caught in seconds rather
    # than after a full xcodebuild test run.
    bash "$here/no_bare_print.sh"
    # The greyscale check (the roadmap's "greyscale check for every new
    # distinction"), and its calibration: the check has to be able to fail, so
    # the calibration plants a distinction that fails in greyscale and reads
    # the verdict by its message. Both before the swift gate, for the same
    # reason the print check is.
    bash "$here/greyscale_gate_test.sh"
    bash "$here/greyscale_gate.sh"
    "$GOH/gates/swift_gate.sh" .
    # The architectures the app SHIPS are checked against the ones the repo
    # DECLARES (G6). After the swift gate on purpose: that gate wipes .build
    # when it is cold, so a Release build made before it would be deleted
    # before it could be read. The calibration runs first because it is fast
    # and it is what says the checker can still fail.
    bash "$here/arch_gate_test.sh"
    bash "$here/arch_gate.sh"
    # No Python layers: koffee_etl/ (USDA nutrition + Wger exercise pipeline)
    # was removed 2026-09 - non-coffee feature strip.
    ;;
esac
