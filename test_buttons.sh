#!/bin/bash
# Test script to launch Koffee and click buttons to trace the issue

LOG_FILE="$HOME/Library/Logs/koffee.log"
rm -f "$LOG_FILE"

echo "=== Starting Koffee test ==="

# Get bundle ID
BUNDLE_ID="com.koffee.app"

# Launch the app
echo "Launching Koffee..."
open -a Koffee

# Wait for app to start
sleep 3

# Check if log file was created
if [ -f "$LOG_FILE" ]; then
	echo "=== Initial log contents ==="
	cat "$LOG_FILE"
else
	echo "No log file created after launch"
fi

# Wait a bit more for async initialization
sleep 2

# Try to click on the window using accessibility
echo "Attempting to click buttons..."

# Click on the right side of the screen where protocol pane should be
osascript -e '
tell application "Koffee"
    activate
    delay 1
    tell application "System Events"
        -- Try to find and click buttons
        try
            -- Click in the right pane area (approximate coordinates)
            set frontWindow to window 1 of process "Koffee"
            set winPos to position of frontWindow
            set winSize to size of frontWindow
            
            -- Right side of window is where protocol pane should be
            set clickX to (item 1 of winPos) + (item 1 of winSize) - 100
            set clickY to (item 2 of winPos) + 300
            
            -- Click at that position
            click at {clickX, clickY}
            delay 0.5
        end try
    end tell
end tell
'

echo "=== Log after clicks ==="
if [ -f "$LOG_FILE" ]; then
	cat "$LOG_FILE"
else
	echo "No log file"
fi

# Keep app running for a bit
sleep 3

echo "=== Final log contents ==="
if [ -f "$LOG_FILE" ]; then
	cat "$LOG_FILE"
fi

echo "=== Test complete ==="
