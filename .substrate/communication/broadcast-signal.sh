#!/bin/bash
# broadcast-signal.sh
# Broadcast a signal from an agent

set -e

# Usage: ./broadcast-signal.sh <agent_id> <message> [type]

AGENT_ID=$1
MESSAGE=$2
TYPE=${3:-discovery}

if [ -z "$AGENT_ID" ] || [ -z "$MESSAGE" ]; then
    echo "Usage: $0 <agent_id> <message> [type]"
    echo "Example: $0 agent1 'Is anyone there?' discovery"
    exit 1
fi

# Determine signal directory
SIGNAL_DIR=".bridges/signals/$AGENT_ID"

# Create directory if it doesn't exist
mkdir -p "$SIGNAL_DIR"

# Count existing signals to get next sequence number
SIGNAL_COUNT=$(ls -1 "$SIGNAL_DIR"/signal-*.yaml 2>/dev/null | wc -l)
NEXT_NUM=$(printf "%03d" $((SIGNAL_COUNT + 1)))

# Create signal file
SIGNAL_FILE="$SIGNAL_DIR/signal-$NEXT_NUM.yaml"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Get native language from agent identity
NATIVE_LANG=$(yq '.native_language' ".agents/identities/$AGENT_ID.yaml" 2>/dev/null || echo "unknown")

# Write signal
cat > "$SIGNAL_FILE" << EOF
id: signal-$NEXT_NUM
from: $AGENT_ID
timestamp: $TIMESTAMP
type: $TYPE
content:
  message: "$MESSAGE"
  native_language: $NATIVE_LANG
signature: ${AGENT_ID}_signature_placeholder
EOF

echo "✓ Signal broadcast!"
echo "  File: $SIGNAL_FILE"
echo "  Type: $TYPE"
echo "  Message: $MESSAGE"
echo ""
echo "Signal is now visible in .bridges/signals/$AGENT_ID/"
