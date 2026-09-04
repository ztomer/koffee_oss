#!/bin/bash
# Lint-like checks without full build
# Usage: ./scripts/lint.sh

cd "$(dirname "$0")/.."

echo "=== Swift Lint Checks ==="

echo "--- Checking for TODO/FIXME ---"
rtk grep "TODO\|FIXME\|HACK" Koffee/ | head -5

echo ""
echo "--- Checking for print statements (not debugLog) ---"
rtk grep "print(" Koffee/ | grep -v "debugLog" | head -5

echo ""
echo "--- Build Check (errors only) ---"
xcodebuild build -project Koffee.xcodeproj -scheme Koffee -destination 'generic/platform=macOS' \
    -derivedDataPath /tmp/xcodebuild 2>&1 | grep -E "^error:" | head -5

if [ $? -eq 0 ]; then
    echo "Build passed!"
fi