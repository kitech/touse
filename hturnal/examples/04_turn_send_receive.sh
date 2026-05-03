#!/bin/bash
# TURN Send/Receive Example
# Demonstrates sending and receiving messages via TURN relay
# Requires a relay to be allocated first

SERVER="http://localhost:8181"

# Check if RELAY_ID is provided
if [ -z "$RELAY_ID" ]; then
    echo "Please allocate a relay first:"
    echo "  source ./examples/03_turn_allocate.sh"
    echo "  or set RELAY_ID manually: export RELAY_ID=\"your_relay_id\""
    exit 1
fi

echo "=== TURN Send/Receive Example ==="
echo "Using relay_id: $RELAY_ID"
echo ""

# Step 1: Add permission for peer
echo "Step 1: Adding permission for peer 'peer1'..."
curl -s -X POST \
  -H "Content-Type: application/json" \
  -d "{\"relay_id\":\"$RELAY_ID\",\"peer_id\":\"peer1\"}" \
  "${SERVER}/turn/permission" | jq '.' 2>/dev/null
echo ""

# Step 2: Send a message
echo "Step 2: Sending message to peer1..."
# Message: "Hello from curl!" encoded in base64
DATA=$(echo -n "Hello from curl!" | base64)
curl -s -X POST \
  -H "Content-Type: application/json" \
  -d "{\"relay_id\":\"$RELAY_ID\",\"peer_id\":\"peer1\",\"data\":\"$DATA\"}" \
  "${SERVER}/turn/send" | jq '.' 2>/dev/null
echo ""

# Step 3: Receive messages (long-poll, waits up to 5 seconds)
echo "Step 3: Receiving messages (waiting up to 5 seconds)..."
RECEIVE_RESP=$(curl -s "${SERVER}/turn/receive?relay_id=${RELAY_ID}&timeout=5")
echo "$RECEIVE_RESP" | jq '.' 2>/dev/null || echo "$RECEIVE_RESP"
echo ""

if command -v jq &> /dev/null; then
    MSG_COUNT=$(echo "$RECEIVE_RESP" | jq '.messages | length')
    echo "Received $MSG_COUNT message(s)"
    if [ "$MSG_COUNT" -gt 0 ]; then
        echo "$RECEIVE_RESP" | jq -r '.messages[] | "From: \(.from)\nData (base64): \(.data)\nTimestamp: \(.timestamp)\n---"'
    fi
fi
