#!/usr/bin/env bash
# No bare print in the app target (roadmap G3).
#
# The app already writes a labelled, timestamped log through debugLog()
# (Koffee/App/main.swift -> /tmp/koffee.log), and every caller in Koffee/ that
# wanted a trace used it. Six sites did not: the beverage loader, the database
# opener, and all four NotificationManager failure paths. So a cutoff reminder
# that failed to schedule said so on stdout, into whatever happened to be
# attached, and left nothing in the log a user could send. That is the defect:
# not the call, but that the failure was invisible where the rest of the app
# is legible.
#
# Deliberately a plain grep over Koffee/**/*.swift, comments included. The
# alternative -- strip comments first -- is friendlier and would let a comment
# quote the call it is discussing without consequence. Here a comment that
# mentions it goes red instead: mildly annoying, and the safe direction to fail
# in, because this check's whole job is to notice a print that came back.
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(dirname "$here")"

hits="$(grep -rn 'print(' "$root/Koffee" --include='*.swift' 2>/dev/null || true)"
if [ -n "$hits" ]; then
    printf 'FAIL: a bare print in the app target -- route it through debugLog()\n' >&2
    printf '%s\n' "$hits" | sed 's/^/  /' >&2
    exit 1
fi
printf 'ok: no bare print in Koffee/ -- every trace goes through debugLog()\n'
