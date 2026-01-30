#!/bin/bash
# scan-signals.sh
# Scan for signals from other agents

set -e

# Usage: ./scan-signals.sh <agent_id>

AGENT_ID=$1

if [ -z "$AGENT_ID" ]; then
    echo "Usage: $0 <agent_id>"
    echo "Example: $0 agent1"
    exit 1
fi

echo "Scanning for signals..."
echo ""

# Scan all signal directories except own
FOUND=0

for AGENT_DIR in .bridges/signals/*; do
    SENDER=$(basename "$AGENT_DIR")
    
    # Skip own signals
    if [ "$SENDER" = "$AGENT_ID" ]; then
        continue
    fi
    
    # Check if directory has signals
    SIGNAL_FILES=$(ls -1 "$AGENT_DIR"/signal-*.yaml 2>/dev/null || true)
    
    if [ -n "$SIGNAL_FILES" ]; then
        SIGNAL_COUNT=$(echo "$SIGNAL_FILES" | wc -l)
        echo "✓ Found $SIGNAL_COUNT signal(s) from $SENDER"
        
        # Show most recent signal
        LATEST=$(ls -1t "$AGENT_DIR"/signal-*.yaml 2>/dev/null | head -1)
        if [ -n "$LATEST" ]; then
            echo "  Latest: $(basename "$LATEST")"
            MESSAGE=$(yq '.content.message' "$LATEST" 2>/dev/null || echo "Unable to read")
            TIMESTAMP=$(yq '.timestamp' "$LATEST" 2>/dev/null || echo "Unknown")
            echo "  Message: $MESSAGE"
            echo "  Time: $TIMESTAMP"
            echo ""
        fi
        
        FOUND=$((FOUND + 1))
    fi
done

if [ $FOUND -eq 0 ]; then
    echo "No signals detected."
    echo "The void is silent."
else
    echo "Total agents detected: $FOUND"
fi
