#!/bin/bash
# Grep with context
# Usage: ./scripts/grep.sh "pattern" [lines_of_context]

cd "$(dirname "$0")/.."
PATTERN="${1?}"
CONTEXT="${2:-2}"

rtk grep "$PATTERN" Koffee/ | while read file line content; do
    echo "--- $file:$line ---"
    sed -n "$((line-$CONTEXT)),$((line+$CONTEXT))p" "$file" 2>/dev/null | head -$((CONTEXT*2+1))
    echo ""
done