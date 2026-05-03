#!/bin/bash
# STUN Binding Example
# Gets the client's public address (mapped address) via HTTP STUN

SERVER="http://localhost:8181"

echo "=== STUN Binding Example ==="
echo "Requesting public address for client_id: test1"
echo ""

RESPONSE=$(curl -s -X POST \
  -H "Content-Type: application/json" \
  -d '{"client_id":"test1"}' \
  "${SERVER}/stun/binding")

echo "Response:"
echo "$RESPONSE" | jq '.' 2>/dev/null || echo "$RESPONSE"
echo ""

# Extract mapped_address if jq is available
if command -v jq &> /dev/null; then
    MAPPED=$(echo "$RESPONSE" | jq -r '.mapped_address')
    echo "Your public address: $MAPPED"
fi
