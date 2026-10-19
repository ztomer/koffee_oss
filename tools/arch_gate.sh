#!/usr/bin/env bash
# The architectures the app SHIPS are checked against the ones the repo DECLARES.
#
# The defect this closes: the Release build was arm64-only because project.yml said
# `ARCHS: "arm64"`, and nothing failed if an x86_64 slice came back. A setting that is
# only a setting is a convention. The house rule (target-platform-policy) is that an
# unsupported architecture is a HARD FAILURE -- never a warning that builds anyway and
# ships a binary nobody has run.
#
# The supported set is read from ONE declared source: project.yml's ARCHS. A second copy
# of it inside this script would be a second policy, and a policy that can disagree with
# the build is not a policy.
#
#   tools/arch_gate.sh                # build Release, then check the product
#   tools/arch_gate.sh --binary PATH  # check a binary that already exists -- the seam the
#                                     # calibration (tools/arch_gate_test.sh) drives
#   tools/arch_gate.sh --project PATH # read the declared set from another project file
#
# Fails closed: no binary, no declared ARCHS, an unreadable project file -- red, never a
# pass because the checker could not read its subject.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(dirname "$here")"
GOH="${GOH_DIR:-${GOH:-$HOME/Projects/gates_of_heck}}"

if [ ! -f "$GOH/tui/lib.sh" ]; then
	printf '✗ arch gate: no gates_of_heck TUI at %s -- clone gates_of_heck there, or set GOH_DIR\n' "$GOH" >&2
	exit 2
fi
# shellcheck disable=SC1091
source "$GOH/tui/lib.sh"

binary=""
project="$root/project.yml"
derived="$root/.build/arch-gate"

while [ $# -gt 0 ]; do
	case "$1" in
	--binary)
		[ $# -ge 2 ] || { err "--binary needs a path"; exit 2; }
		binary="$2"
		shift 2
		;;
	--project)
		[ $# -ge 2 ] || { err "--project needs a path"; exit 2; }
		project="$2"
		shift 2
		;;
	-h | --help)
		printf 'usage: tools/arch_gate.sh [--binary PATH] [--project PATH]\n'
		exit 0
		;;
	*)
		err "unknown argument '$1' (accepted: --binary PATH, --project PATH)"
		exit 2
		;;
	esac
done

# Normalize an architecture list to a sorted, space-separated set. "arm64 arm64" and
# "arm64" are the same set; "x86_64 arm64" and "arm64 x86_64" are the same set too, and
# lipo prints them in either order depending on how the fat file was made.
normalize_archs() {
	printf '%s\n' "$1" | tr ' ' '\n' | grep -v '^$' | sort -u | tr '\n' ' ' | sed 's/ *$//' || true
}

# The DECLARED supported set: project.yml's ARCHS.
#
# Every ARCHS line in the file must agree. Two that do not is an ambiguous declaration,
# and an ambiguous declaration is red rather than a guess.
declared_archs() {
	local file="$1" values unique count
	if [ ! -f "$file" ]; then
		err "no project file at $file"
		return 1
	fi
	values="$(awk '
		/^[[:space:]]*ARCHS[[:space:]]*:/ {
			value = $0
			sub(/^[^:]*:[[:space:]]*/, "", value)
			gsub(/["\047]/, "", value)
			gsub(/[[:space:]]+/, " ", value)
			gsub(/^ | $/, "", value)
			if (value != "") print value
		}
	' "$file")"
	if [ -z "$values" ]; then
		err "$file declares no ARCHS -- there is no supported set to check against"
		return 1
	fi
	unique="$(printf '%s\n' "$values" | sort -u)"
	count="$(printf '%s\n' "$unique" | grep -c . || true)"
	if [ "$count" -gt 1 ]; then
		err "$file declares ARCHS more than one way, and they disagree:"
		printf '%s\n' "$unique" | sed 's/^/  /' >&2
		return 1
	fi
	normalize_archs "$unique"
}

# The architectures actually IN a binary. lipo is the reader that knows about fat files;
# `file` would only ever see the outer header.
built_archs() {
	local file="$1" archs
	if [ ! -f "$file" ]; then
		err "no binary at $file"
		return 1
	fi
	if ! archs="$(lipo -archs "$file" 2>/dev/null)"; then
		err "lipo cannot read $file as a Mach-O"
		return 1
	fi
	if [ -z "$(normalize_archs "$archs")" ]; then
		err "$file reports no architectures"
		return 1
	fi
	normalize_archs "$archs"
}

# Every Mach-O the app ships: the executable, plus anything embedded in the bundle.
# A dynamic framework with its own slice is shipped code too.
bundle_binaries() {
	local bundle="$1" found=""
	[ -d "$bundle/Contents/Frameworks" ] || return 0
	for candidate in "$bundle"/Contents/Frameworks/*/Contents/MacOS/*; do
		[ -f "$candidate" ] || continue
		found="$found $candidate"
	done
	printf '%s' "$found"
}

info "arch gate: the shipped architectures against the declared ones"

declared="$(declared_archs "$project")" || die "the supported set is unreadable -- refusing to pass a check that read nothing"
[ -n "$declared" ] || die "the supported set is empty -- refusing to pass a check that read nothing"
step "declared (ARCHS in $project): $declared"

if [ -n "$binary" ]; then
	targets="$binary"
else
	command -v xcodegen >/dev/null || {
		printf '✗ arch gate: xcodegen not found: the gate builds the project it checks (brew install xcodegen)\n' >&2
		exit 2
	}
	if [ ! -d "$root/Koffee.xcodeproj" ]; then
		step "generating Koffee.xcodeproj from project.yml"
		xcodegen generate --quiet --spec "$project"
	fi
	log="$derived/arch-gate-build.log"
	mkdir -p "$derived"
	step "building Release (the configuration that ships)"
	if ! xcodebuild -project "$root/Koffee.xcodeproj" -scheme Koffee -configuration Release \
		-derivedDataPath "$derived" build >"$log" 2>&1; then
		err "the Release build failed; the tail of $log:"
		tail -n 20 "$log" >&2
		die "there is no binary to check the architectures of"
	fi
	bundle="$derived/Build/Products/Release/Koffee.app"
	targets="$bundle/Contents/MacOS/Koffee $(bundle_binaries "$bundle")"
fi

failures=0
for target in $targets; do
	archs="$(built_archs "$target")" || {
		err "$target could not be read"
		failures=$((failures + 1))
		continue
	}
	step "$(basename "$target"): $archs"
	# Any architecture the repo does not declare is a hard failure -- not a warning that
	# builds anyway. The unsupported slice is the thing that shipped before.
	unsupported=""
	for arch in $archs; do
		case " $declared " in
		*" $arch "*) ;;
		*) unsupported="$unsupported $arch" ;;
		esac
	done
	if [ -n "$unsupported" ]; then
		unsupported_list="$(printf '%s' "$unsupported" | sed 's/^ //; s/ /, /g')"
		err "$(basename "$target") ships architecture(s) this repo does not declare: $unsupported_list"
		err "  declared (ARCHS in $project): $declared"
		err "  built: $archs"
		failures=$((failures + 1))
	fi
done

if [ "$failures" -gt 0 ]; then
	die "$failures shipped binaries carry an architecture this repo does not declare -- macOS here is Apple silicon only"
fi

ok "every shipped binary is $declared -- the declared set, and nothing else"
