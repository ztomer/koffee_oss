#!/bin/bash
# Run tests with coverage report
# Usage: ./scripts/run_tests.sh

cd "$(dirname "$0")/.."

echo "=== Running Tests ==="
xcodebuild test \
    -project Koffee.xcodeproj \
    -scheme KoffeeTests \
    -destination 'platform=macOS' \
    -enableCodeCoverage YES \
    -resultBundlePath TestResults 2>&1 | grep -E "TEST|PASS|FAIL|error:|warning:"

echo ""
echo "=== Test Results ==="
if [ -d TestResults ]; then
    xcrun simctl list devices available | head -5
fi