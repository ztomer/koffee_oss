#!/bin/bash
# Show test coverage status
# Usage: ./scripts/test_coverage.sh

cd "$(dirname "$0")/.."

echo "=== Test Coverage ==="
echo ""

echo "--- Files in tests ---"
rtk grep "func test" KoffeeTests/ | sed 's/KoffeeTests.*test_//' | sed 's/.swift.*://' | sed 's/_test.*//' | sort | uniq

echo ""
echo "--- Main files ---"
find Koffee -name "*.swift" -type f -not -path "*/\.*" | wc -l | xargs echo "Total Swift files:"

echo ""
echo "Note: Run 'xcodebuild test' to see actual coverage"