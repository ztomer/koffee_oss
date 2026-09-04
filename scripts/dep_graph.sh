#!/bin/bash
# Generate import/dependency graph
# Usage: ./scripts/dep_graph.sh [file]

cd "$(dirname "$0")/.."
TARGET="${1:-}"

if [ -z "$TARGET" ]; then
    echo "=== Dependency Graph ==="
    echo "Top-level imports (what imports what):"
    echo ""
    
    for file in Koffee/Data/*.swift Koffee/Domain/*.swift Koffee/UI/*.swift; do
        name=$(basename "$file" .swift)
        imports=$(rtk grep "import" "$file" | grep -v "import Foundation" | grep -v "import SwiftUI" | grep -v "import Combine" | grep -v "import GRDB" | sed 's/.*import /import /')
        if [ -n "$imports" ]; then
            echo "$name -> $imports"
        fi
    done | head -30
else
    echo "=== Dependencies of: $TARGET ==="
    rtk grep "import\|@\"" "$TARGET" | head -20
fi