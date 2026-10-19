#!/usr/bin/env bash
# Calibration for tools/arch_gate.sh: the checker must be ABLE to fail.
#
# A gate nobody has seen go red is a gate being trusted blind. This drives the checker
# with real Mach-O fixtures -- the architectures the repo declares (it must pass), an
# architecture it does not (it must fail), a UNIVERSAL binary carrying a slice that came
# back (it must fail, and it must name the slice), and a missing binary and an
# unreadable declaration (it must fail closed).
#
# The fixtures are built here rather than committed: a committed fat binary is a binary
# nobody can read in a diff, and this one has to be regenerated on the machine that runs
# the gate anyway (it needs a compiler and lipo).
#
# Every red is read by its MESSAGE, not only by its exit code: a gate that exits 1 for
# the wrong reason is not the gate under test.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(dirname "$here")"
gate="$here/arch_gate.sh"
GOH="${GOH_DIR:-${GOH:-$HOME/Projects/gates_of_heck}}"

if [ ! -f "$GOH/tui/lib.sh" ]; then
	printf '✗ arch gate calibration: no gates_of_heck TUI at %s -- clone gates_of_heck there, or set GOH_DIR\n' "$GOH" >&2
	exit 2
fi
# shellcheck disable=SC1091
source "$GOH/tui/lib.sh"

require_commands clang lipo

info "arch gate calibration: the checker must be able to fail"

declared="$(awk '
	/^[[:space:]]*ARCHS[[:space:]]*:/ {
		value = $0
		sub(/^[^:]*:[[:space:]]*/, "", value)
		gsub(/["\047]/, "", value)
		gsub(/[[:space:]]+/, " ", value)
		gsub(/^ | $/, "", value)
		if (value != "") { print value; exit }
	}
' "$root/project.yml")"

if [ -z "$declared" ]; then
	die "project.yml declares no ARCHS -- nothing to calibrate against"
fi

# The first declared architecture is the one the fixtures are built for.
supported="${declared%% *}"
case " $declared " in
*" x86_64 "*) unsupported="arm64" ;;
*) unsupported="x86_64" ;;
esac

step "declared: $declared  (supported fixture: $supported, unsupported: $unsupported)"

work="$(mktemp -d "${TMPDIR:-/tmp}/koffee-arch-gate.XXXXXX")"
trap 'rm -rf "$work"' EXIT

cat >"$work/fixture.c" <<'EOF'
/* A Mach-O with nothing in it: the gate reads architectures, not behaviour. */
int main(void) { return 0; }
EOF

clang -arch "$supported" -o "$work/supported" "$work/fixture.c"
clang -arch "$unsupported" -o "$work/unsupported" "$work/fixture.c"
lipo -create "$work/supported" "$work/unsupported" -output "$work/universal"

# A project file with no ARCHS at all: the declaration the gate cannot read.
printf 'name: Koffee\nsettings:\n  base:\n    PRODUCT_NAME: Koffee\n' >"$work/no-archs.yml"

failures=0

# Runs the gate, keeps its output, and returns its exit code.
run_gate() {
	local out rc=0
	out="$(bash "$gate" --project "$root/project.yml" "$@" 2>&1)" || rc=$?
	printf '%s' "$out" >"$work/gate-output.txt"
	return "$rc"
}

expect_pass() {
	local what="$1"
	shift
	if run_gate "$@"; then
		ok "$what -- the gate passed it, as it should"
	else
		err "$what -- the gate REFUSED something it should accept"
		sed 's/^/  /' "$work/gate-output.txt" >&2
		failures=$((failures + 1))
	fi
}

expect_fail() {
	local what="$1" must_mention="$2"
	shift 2
	if run_gate "$@"; then
		err "$what -- the gate PASSED something it must refuse"
		sed 's/^/  /' "$work/gate-output.txt" >&2
		failures=$((failures + 1))
		return
	fi
	if [ -n "$must_mention" ] && ! grep -q "$must_mention" "$work/gate-output.txt"; then
		err "$what -- the gate failed, but its message does not name '$must_mention'"
		sed 's/^/  /' "$work/gate-output.txt" >&2
		failures=$((failures + 1))
		return
	fi
	ok "$what -- the gate refused it, and said why"
}

expect_pass "a binary built for the declared architecture" --binary "$work/supported"
expect_fail "a binary built for an undeclared architecture" "$unsupported" --binary "$work/unsupported"
expect_fail "a universal binary with the slice that came back" "$unsupported" --binary "$work/universal"
expect_fail "a binary that is not there" "no binary" --binary "$work/not-built"

# Fail closed: a declaration the gate cannot read is red, never a pass.
if bash "$gate" --project "$work/no-archs.yml" --binary "$work/supported" >"$work/gate-output.txt" 2>&1; then
	err "a project file with no ARCHS -- the gate PASSED a declaration it could not read"
	failures=$((failures + 1))
else
	ok "a project file with no ARCHS -- the gate refused to pass a declaration it could not read"
fi

if [ "$failures" -gt 0 ]; then
	die "$failures calibration case(s) behaved wrongly -- the arch gate is not trusted until they all hold"
fi

ok "the arch gate is calibrated: it passes the declared set and refuses everything else"
