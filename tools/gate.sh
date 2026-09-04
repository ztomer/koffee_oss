#!/usr/bin/env bash
# Per-repo gate entry point. Declares which toolchains this repo contains and
# delegates; it holds no gate logic of its own.
#   --staged : pre-commit scope (fast) — layer 1 only
#   --full   : pre-push scope — every layer
set -euo pipefail
GOH="${GOH_DIR:-${GOH:-$HOME/Projects/gates_of_heck}}"

"$GOH/gates/structural.sh" "$@"

case "${1:-}" in
  --full)
    # Per-language layers for what this repo actually contains:
    #
    # swift: Koffee app (xcodebuild) + LiquidContainer SPM package.
    #   Lint debt cleared 2026-08 - swiftlint --strict is green.
    #   Coverage floor not set yet (GOH_SWIFT_COV_MIN in .gatesrc).
    "$GOH/gates/swift_gate.sh" .
    #
    # py: koffee_etl/ has ruff-clean sources but NO pytest suite. py_gate
    #   runs `pytest -q`, which fails on a zero-test run, so the layer is
    #   wired only when a real test suite lands. Ruff debt itself is fixed.
    #   To wire later: add tests, then uncomment:
    #   "$GOH/gates/py_gate.sh"    koffee_etl
    ;;
esac
