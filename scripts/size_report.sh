#!/bin/bash
# Report file sizes sorted largest first
cd "$(dirname "$0")/.."

echo "=== Swift File Sizes (sorted largest) ==="
rtk wc -l Koffee/**/*.swift 2>/dev/null | sort -rn | head -20

echo ""
echo "=== Files over 500 lines ==="
rtk wc -l Koffee/**/*.swift 2>/dev/null | awk '$1 > 500 {print}'

echo ""
echo "=== Count: ≤500 vs >500 ==="
total=$(rtk wc -l Koffee/**/*.swift 2>/dev/null | wc -l | tr -d ' ')
over=$(rtk wc -l Koffee/**/*.swift 2>/dev/null | awk '$1 > 500' | wc -l | tr -d ' ')
under=$((total - over))
echo "Total: $total | ≤500: $under | >500: $over"