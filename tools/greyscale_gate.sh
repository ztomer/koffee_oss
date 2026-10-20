#!/usr/bin/env bash
# The greyscale check: every visual distinction must survive the removal of the colour channel.
#
# The roadmap's "Recurring gates" has said, since it was written: "Greyscale single-channel
# check on every new visual distinction." That was DISCIPLINE, not automation: nothing ran it,
# so a distinction that fails in greyscale passed the gate silently. This is the harness.
#
# WHAT IT CHECKS. A "visual distinction" is a set of mutually exclusive states of the app that
# the UI tells apart by COLOUR. The house rule is that no distinction rides on one channel --
# colour reinforces, shape and text carry -- so the question this asks is: with the colour
# channel removed, is the state still identifiable?
#
#   tools/greyscale_gate.sh              # check the repo
#   tools/greyscale_gate.sh --root PATH  # check a copy of it (the calibration does)
#
# The states are DISCOVERED in the sources (an if/else chain, a switch, a ternary chain), not
# read from a list: a list would go stale, and a stale list is a gate that checks the wrong
# thing. Every colour is MEASURED through AppKit in the light and the dark appearance, and
# turned into the greyscale the reader would actually see. A distinction carried by colour
# alone, whose colours are closer than the threshold, is red, and it is named: the file, the
# declaration, the two states, their colours, and the measured gap.
#
# The checker is a small Swift program (tools/greyscale/) because the colours have to be
# resolved through the platform: a table of remembered RGB values is a table that rots.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(dirname "$here")"
# The gates checkout is not needed here: the check is this repo's own.

# The toolchain: Xcode's, and through `xcrun`, because a swiftly toolchain on PATH shadows
# it and cannot find the platform SDK (the same trap the house swift gate documents). The
# compiler is invoked through `xcrun` for the same reason: the toolchain's `swiftc` on its own
# cannot load the standard library for this target.
swift_compile=""
if command -v xcrun >/dev/null 2>&1 && xcrun --find swiftc >/dev/null 2>&1; then
	swift_compile="xcrun swiftc"
elif command -v swiftc >/dev/null 2>&1; then
	swift_compile="swiftc"
fi
if [ -z "$swift_compile" ]; then
	printf '✗ greyscale gate: no swiftc on this machine -- the check needs a Swift toolchain\n' >&2
	exit 2
fi

build="$(mktemp -d "${TMPDIR:-/tmp}/koffee-greyscale.XXXXXX")"
trap 'rm -rf "$build"' EXIT

# shellcheck disable=SC2086
if ! $swift_compile -o "$build/greyscale" "$here"/greyscale/*.swift; then
	printf '✗ greyscale gate: the checker did not build\n' >&2
	exit 2
fi

"$build/greyscale" --root "$root" "$@"
exit $?
