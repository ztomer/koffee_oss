#!/bin/bash
# Full test suite: LiquidContainer package + Koffee app tests.
set -euo pipefail
GOH="${GOH_DIR:-${GOH:-$HOME/Projects/gates_of_heck}}"
# shellcheck disable=SC1091
source "$GOH/tui/lib.sh"

section "Koffee Test Suite"

TOTAL_FAILURES=0

# 1. LiquidContainer Tests
info "Running LiquidContainer tests..."
cd LiquidContainer
if swift test 2>&1 | tee /tmp/koffee_test_liquid.log; then
	ok "LiquidContainer tests passed"
else
	err "LiquidContainer tests failed"
	TOTAL_FAILURES=$((TOTAL_FAILURES + 1))
fi
cd ..
echo ""

# 2. KoffeeTests
info "Running Koffee app tests..."
xcodebuild test -project Koffee.xcodeproj -scheme KoffeeTests -destination 'platform=macOS' 2>&1 | tee /tmp/koffee_test_app.log

# Check for actual test failures in the output (xcodebuild exit code is unreliable with test hosts)
testing_failed="$(grep "Testing failed:" /tmp/koffee_test_app.log || true)"
if grep -q "with [1-9][0-9]* failure" /tmp/koffee_test_app.log \
	|| { [ -n "$testing_failed" ] && grep -qv "TEST FAILED" <<< "$testing_failed"; }; then
	err "Koffee app tests failed"
	TOTAL_FAILURES=$((TOTAL_FAILURES + 1))
else
	ok "Koffee app tests passed"
fi
echo ""

# Summary
section "Test Summary"

# Extract test counts
LIQUID_COUNT=$(grep -o 'Executed [0-9]* tests' /tmp/koffee_test_liquid.log | tail -1 || echo "0 tests")
APP_COUNT=$(grep -o 'Executed [0-9]* tests' /tmp/koffee_test_app.log | tail -1 || echo "0 tests")

echo "LiquidContainer: $LIQUID_COUNT"
echo "Koffee App:      $APP_COUNT"
echo ""

if [ $TOTAL_FAILURES -eq 0 ]; then
	ok "All test suites passed!"
	exit 0
else
	echo "Failures:"
	failures="$(grep -E "error:|failed.*failure" /tmp/koffee_test_app.log || true)"
	head -n 20 <<< "$failures"
	echo ""
	die "$TOTAL_FAILURES test suite(s) failed"
fi
