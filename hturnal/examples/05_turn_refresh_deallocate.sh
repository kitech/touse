#!/bin/bash
# TURN Refresh and Deallocate Example
# Refreshes allocation lifetime and deallocates the relay

SERVER="http://localhost:8181"

# Check if RELAY_ID is provided
if [ -z "$RELAY_ID" ]; then
    echo "Please allocate a relay first:"
    echo "  source ./examples/03_turn_allocate.sh"
    echo "  or set RELAY_ID manually: export RELAY_ID=\"your_relay_id\""
    exit 1
fi

echo "=== TURN Refresh/Deallocate Example ==="
echo "Using relay_id: $RELAY_ID"
echo ""

# Step 1: Refresh the allocation (extend lifetime)
echo "Step 1: Refreshing allocation (new lifetime: 600 seconds)..."
REFRESH_RESP=$(curl -s -X POST \
  -H "Content-Type: application/json" \
  -d "{\"relay_id\":\"$RELAY_ID\",\"lifetime\":600}" \
  "${SERVER}/turn/refresh")

echo "Refresh Response:"
echo "$REFRESH_RESP" | jq '.' 2>/dev/null || echo "$REFRESH_RESP"
echo ""

# Step 2: Deallocate the relay
echo "Step 2: Deallocating relay..."
DEALLOC_RESP=$(curl -s -X POST \
  -H "Content-Type: application/json" \
  -d "{\"relay_id\":\"$RELAY_ID\"}" \
  "${SERVER}/turn/deallocate")

echo "Deallocate Response:"
echo "$DEALLOC_RESP" | jq '.' 2>/dev/null || echo "$DEALLOC_RESP"
echo ""

echo "Relay $RELAY_ID has been deallocated."
echo "Unset the variable: unset RELAY_ID"
