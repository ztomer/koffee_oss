#!/bin/bash
# Quick build check - fast compile without running
# Usage: ./scripts/quick_build.sh

cd "$(dirname "$0")/.."

echo "=== Quick Build Check ==="
xcodegen generate 2>&1 | tail -2
xcodebuild build -project Koffee.xcodeproj -scheme Koffee -destination 'generic/platform=macOS' 2>&1 | grep -E "BUILD|error:" | tail -3