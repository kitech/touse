#!/bin/bash
# TURN Allocate Example
# Allocates a TURN relay resource

SERVER="http://localhost:8181"

echo "=== TURN Allocate Example ==="
echo "Allocating relay for client_id: test1"
echo ""

RESPONSE=$(curl -s -X POST \
  -H "Content-Type: application/json" \
  -d '{"client_id":"test1"}' \
  "${SERVER}/turn/allocate")

echo "Response:"
echo "$RESPONSE" | jq '.' 2>/dev/null || echo "$RESPONSE"
echo ""

if command -v jq &> /dev/null; then
    RELAY_ID=$(echo "$RESPONSE" | jq -r '.relay_id')
    RELAY_ADDR=$(echo "$RESPONSE" | jq -r '.relay_address')
    LIFETIME=$(echo "$RESPONSE" | jq -r '.lifetime')
    echo "Relay ID: $RELAY_ID"
    echo "Relay Address: $RELAY_ADDR"
    echo "Lifetime: $LIFETIME seconds"
    echo ""
    echo "Save this for later use:"
    echo "export RELAY_ID=\"$RELAY_ID\""
fi
