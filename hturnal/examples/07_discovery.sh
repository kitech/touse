#!/bin/bash
# Discovery Example
# Gets the list of available STUN/TURN servers from the discovery endpoint

SERVER="http://localhost:8181"

echo "=== Discovery Example ==="
echo "Fetching server list from: ${SERVER}/discovery/servers"
echo ""

RESPONSE=$(curl -s "${SERVER}/discovery/servers")

echo "Response:"
echo "$RESPONSE" | jq '.' 2>/dev/null || echo "$RESPONSE"
echo ""

if command -v jq &> /dev/null; then
    echo "STUN Servers:"
    echo "$RESPONSE" | jq -r '.stun_servers[] | "  Type: \(.type)\n  URL: \(.url)\n  NAT Check URL: \(.nat_check_url)\n"'
    echo ""
    echo "TURN Servers:"
    echo "$RESPONSE" | jq -r '.turn_servers[] | "  Type: \(.type)\n  Allocate URL: \(.allocate_url)\n  Send URL: \(.send_url)\n  Receive URL: \(.receive_url)\n"'
    echo ""
    echo "HTTP Only: $(echo "$RESPONSE" | jq -r '.http_only')"
fi
