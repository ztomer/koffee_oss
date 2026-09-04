#!/bin/bash
# Script to split Models.swift

cd /Users/ztomer/Projects/koffee

# 1. First create CaffeineProtocol.swift with all the PK types if not exists
if [ ! -f Koffee/Data/CaffeineProtocol.swift ]; then
    echo "CaffeineProtocol.swift missing - run migration first"
    exit 1
fi

# 2. Check build first
xcodegen generate
xcodebuild build -project Koffee.xcodeproj -scheme KoffeeTests -destination 'platform=macOS' 2>&1 | grep -E "error:|BUILD"

# If duplicate errors, need to comment out in Models.swift
# If SUCCESS, Models.swift extract is done