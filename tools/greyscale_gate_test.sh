#!/usr/bin/env bash
# The calibration: the greyscale check can still fail.
#
# A gate that cannot fail is not a gate. This plants a distinction that fails in greyscale --
# the chart's "At Bedtime" figure, which is red over 50 mg and green under it -- and reads the
# checker's verdict by its MESSAGE, not only by its exit code: a checker that says "red" for
# the wrong reason is not a checker that works.
#
# The plant is made in a COPY of the sources, never in the working tree: the point is to prove
# the check bites, not to break the app on the way to the answer.
#
#   tools/greyscale_gate_test.sh
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(dirname "$here")"

work="$(mktemp -d "${TMPDIR:-/tmp}/koffee-greyscale-calibration.XXXXXX")"
trap 'rm -rf "$work"' EXIT

cp -R "$root/Koffee" "$work/Koffee"
mkdir -p "$work/LiquidContainer"
cp -R "$root/LiquidContainer/Sources" "$work/LiquidContainer/Sources"

# The plant: the chart's over-limit figure goes from red to orange, which in greyscale is the
# same shade as green (1.3 L* apart) -- the distinction would ride on hue alone, and a reader
# with the colour turned off could not tell "over 50 mg" from "under 50 mg".
target="$work/Koffee/UI/UnifiedChartView.swift"
if ! grep -q 'bedtimeCaffeine > 50 ? .red : .green' "$target"; then
	printf 'FAIL: the calibration could not find the plant site in %s -- the checker would be\n' "$target" >&2
	printf '  calibrated against a line that has moved, and a calibration that cannot plant is a\n' >&2
	printf '  calibration that proves nothing.\n' >&2
	exit 1
fi

failures=0
check_red() {
	local label="$1"
	local output
	output="$(bash "$here/greyscale_gate.sh" --root "$work" 2>&1)"
	local status=$?
	if [ "$status" -eq 0 ]; then
		printf 'FAIL: %s: the checker passed a tree that carries a distinction that fails in greyscale\n' "$label" >&2
		printf '%s\n' "$output" >&2
		failures=$((failures + 1))
		return
	fi
	# The verdict is read by its MESSAGE: the file, the two states and the reason.
	local missing=""
	case "$output" in
	*"UnifiedChartView.swift"*) ;;
	*) missing="$missing the-file" ;;
	esac
	case "$output" in
	*".orange"*) ;;
	*) missing="$missing the-colours" ;;
	esac
	case "$output" in
	*"L* apart"*) ;;
	*) missing="$missing the-reason" ;;
	esac
	if [ -n "$missing" ]; then
		printf 'FAIL: %s: the checker went red without saying%s:\n' "$label" "$missing" >&2
		printf '%s\n' "$output" >&2
		failures=$((failures + 1))
		return
	fi
	printf 'ok: %s: the checker went red and named the distinction\n' "$label"
}

# The unplanted tree must be green, or the checker is red for a reason of its own.
if ! bash "$here/greyscale_gate.sh" --root "$work" >/dev/null 2>&1; then
	printf 'FAIL: the unplanted tree is already red -- the check cannot be calibrated on it\n' >&2
	bash "$here/greyscale_gate.sh" --root "$work" || true
	exit 1
fi
printf 'ok: the unplanted tree is green\n'

sed -i '' 's/bedtimeCaffeine > 50 ? .red : .green/bedtimeCaffeine > 50 ? .orange : .green/' "$target"
check_red "the planted distinction"

if [ "$failures" -ne 0 ]; then
	printf 'FAIL: %s calibration check(s) failed\n' "$failures" >&2
	exit 1
fi
printf 'ok: the greyscale check can fail, and it fails by name\n'
