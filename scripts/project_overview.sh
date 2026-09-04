#!/bin/bash
# Generate project overview
# Usage: ./scripts/project_overview.sh

cd "$(dirname "$0")/.."

echo "=== Koffee Project Overview ==="
echo "Generated: $(date)"
echo ""

echo "--- File Count by Directory ---"
find Koffee -name "*.swift" -type f | \
    sed 's|/[^/]*$||' | \
    sort | uniq -c | sort -rn

echo ""
echo "--- Model Count ---"
echo "GRDB Models:"
rtk grep "^struct.*Model:" Koffee/ | wc -l | tr -d ' '
echo "Enums:"
rtk grep "^enum " Koffee/ | grep -v ": " | wc -l | tr -d ' '
echo "Repositories:"
rtk grep "Repository" Koffee/Data/Repositories/ | wc -l | tr -d ' '

echo ""
echo "--- Database Tables ---"
rtk grep "TableRecord\|databaseTableName" Koffee/Data/Models/ Koffee/Data/ | head -10