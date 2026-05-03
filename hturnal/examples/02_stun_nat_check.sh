#!/bin/bash
# STUN NAT Check Example
# Detects the NAT type of the client (simplified version)

SERVER="http://localhost:8181"

echo "=== STUN NAT Check Example ==="
echo "Checking NAT type for client_id: test1"
echo ""

RESPONSE=$(curl -s -X POST \
  -H "Content-Type: application/json" \
  -d '{"client_id":"test1","test_sequence":"full"}' \
  "${SERVER}/stun/nat-check")

echo "Response:"
echo "$RESPONSE" | jq '.' 2>/dev/null || echo "$RESPONSE"
echo ""

if command -v jq &> /dev/null; then
    NAT_TYPE=$(echo "$RESPONSE" | jq -r '.nat_type')
    PUBLIC_IP=$(echo "$RESPONSE" | jq -r '.public_ip')
    echo "NAT Type: $NAT_TYPE"
    echo "Public IP: $PUBLIC_IP"
fi
