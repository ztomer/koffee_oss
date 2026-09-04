#!/bin/bash
# Find where a type is defined across the codebase
# Usage: ./scripts/find_type.sh TypeName

if [ -z "$1" ]; then
    echo "Usage: $0 <TypeName>"
    echo "Finds where a type/function is defined"
    exit 1
fi

echo "=== Definition: $1 ==="
rtk grep -n "^struct $1\|^enum $1\|^class $1\|^func $1" Koffee/ 2>/dev/null

echo ""
echo "=== Usages: $1 ==="
rtk grep "$1" Koffee/ | grep -v "^struct \|^enum \|^class \|^func " | head -15