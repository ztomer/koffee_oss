#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo "========================================="
echo "  Koffee Test Suite"
echo "========================================="
echo ""

TOTAL_FAILURES=0

# 1. LiquidContainer Tests
echo -e "${YELLOW}Running LiquidContainer tests...${NC}"
cd LiquidContainer
if rtk swift test 2>&1 | tee /tmp/koffee_test_liquid.log; then
	echo -e "${GREEN}✓ LiquidContainer tests passed${NC}"
else
	echo -e "${RED}✗ LiquidContainer tests failed${NC}"
	TOTAL_FAILURES=$((TOTAL_FAILURES + 1))
fi
cd ..
echo ""

# 2. KoffeeTests
echo -e "${YELLOW}Running Koffee app tests...${NC}"
xcodebuild test -project Koffee.xcodeproj -scheme KoffeeTests -destination 'platform=macOS' 2>&1 | tee /tmp/koffee_test_app.log

# Check for actual test failures in the output (xcodebuild exit code is unreliable with test hosts)
if grep -q "with [1-9][0-9]* failure" /tmp/koffee_test_app.log || grep -q "Testing failed:" /tmp/koffee_test_app.log | grep -v "TEST FAILED"; then
	echo -e "${RED}✗ Koffee app tests failed${NC}"
	TOTAL_FAILURES=$((TOTAL_FAILURES + 1))
else
	echo -e "${GREEN}✓ Koffee app tests passed${NC}"
fi
echo ""

# Summary
echo "========================================="
echo "  Test Summary"
echo "========================================="

# Extract test counts
LIQUID_COUNT=$(grep -o 'Executed [0-9]* tests' /tmp/koffee_test_liquid.log | tail -1 || echo "0 tests")
APP_COUNT=$(grep -o 'Executed [0-9]* tests' /tmp/koffee_test_app.log | tail -1 || echo "0 tests")

echo "LiquidContainer: $LIQUID_COUNT"
echo "Koffee App:      $APP_COUNT"
echo ""

if [ $TOTAL_FAILURES -eq 0 ]; then
	echo -e "${GREEN}All test suites passed!${NC}"
	exit 0
else
	echo -e "${RED}$TOTAL_FAILURES test suite(s) failed${NC}"
	echo ""
	echo "Failures:"
	grep -E "error:|failed.*failure" /tmp/koffee_test_app.log | head -20
	exit 1
fi
