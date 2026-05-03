#!/bin/bash
# Full Workflow Example
# Demonstrates a complete STUN -> TURN -> Stream workflow

SERVER="http://localhost:8181"
CLIENT_ID="test_client_$(date +%s)"

echo "=== Full Workflow Example ==="
echo "Client ID: $CLIENT_ID"
echo ""

# 1. STUN Binding
echo "1. Getting public address via STUN..."
STUN_RESP=$(curl -s -X POST \
  -H "Content-Type: application/json" \
  -d "{\"client_id\":\"$CLIENT_ID\"}" \
  "${SERVER}/stun/binding")

echo "$STUN_RESP" | jq '.' 2>/dev/null || echo "$STUN_RESP"
PUBLIC_ADDR=$(echo "$STUN_RESP" | jq -r '.mapped_address' 2>/dev/null)
echo "Public Address: $PUBLIC_ADDR"
echo ""

# 2. Allocate TURN relay
echo "2. Allocating TURN relay..."
TURN_RESP=$(curl -s -X POST \
  -H "Content-Type: application/json" \
  -d "{\"client_id\":\"$CLIENT_ID\"}" \
  "${SERVER}/turn/allocate")

echo "$TURN_RESP" | jq '.' 2>/dev/null || echo "$TURN_RESP"
RELAY_ID=$(echo "$TURN_RESP" | jq -r '.relay_id' 2>/dev/null)
echo "Relay ID: $RELAY_ID"
echo ""

# 3. Add permission
echo "3. Adding permission for peer 'peer1'..."
curl -s -X POST \
  -H "Content-Type: application/json" \
  -d "{\"relay_id\":\"$RELAY_ID\",\"peer_id\":\"peer1\"}" \
  "${SERVER}/turn/permission" | jq '.' 2>/dev/null
echo ""

# 4. Send message
echo "4. Sending message to peer1..."
DATA=$(echo -n "Hello from full workflow!" | base64)
curl -s -X POST \
  -H "Content-Type: application/json" \
  -d "{\"relay_id\":\"$RELAY_ID\",\"peer_id\":\"peer1\",\"data\":\"$DATA\"}" \
  "${SERVER}/turn/send" | jq '.' 2>/dev/null
echo ""

# 5. Receive message
echo "5. Receiving messages..."
curl -s "${SERVER}/turn/receive?relay_id=${RELAY_ID}&timeout=3" | jq '.' 2>/dev/null
echo ""

# 6. Start stream
echo "6. Starting stream..."
STREAM_RESP=$(curl -s -X POST \
  -H "Content-Type: application/json" \
  -d "{\"client_id\":\"$CLIENT_ID\",\"peer_id\":\"peer1\"}" \
  "${SERVER}/turn/stream/start")

echo "$STREAM_RESP" | jq '.' 2>/dev/null || echo "$STREAM_RESP"
STREAM_ID=$(echo "$STREAM_RESP" | jq -r '.stream_id' 2>/dev/null)
echo "Stream ID: $STREAM_ID"
echo ""

# 7. Send stream chunk
echo "7. Sending stream chunk..."
CHUNK_DATA=$(echo -n "Stream data in full workflow" | base64)
curl -s -X POST \
  -H "Content-Type: application/json" \
  -d "{\"stream_id\":\"$STREAM_ID\",\"chunk_seq\":0,\"data\":\"$CHUNK_DATA\"}" \
  "${SERVER}/turn/stream/send" | jq '.' 2>/dev/null
echo ""

# 8. Receive stream chunks
echo "8. Receiving stream chunks..."
curl -s "${SERVER}/turn/stream/receive?stream_id=${STREAM_ID}&timeout=3" | jq '.' 2>/dev/null
echo ""

# 9. Clean up - End stream
echo "9. Ending stream..."
curl -s -X POST \
  -H "Content-Type: application/json" \
  -d "{\"stream_id\":\"$STREAM_ID\"}" \
  "${SERVER}/turn/stream/end" | jq '.' 2>/dev/null
echo ""

# 10. Deallocate relay
echo "10. Deallocating relay..."
curl -s -X POST \
  -H "Content-Type: application/json" \
  -d "{\"relay_id\":\"$RELAY_ID\"}" \
  "${SERVER}/turn/deallocate" | jq '.' 2>/dev/null
echo ""

echo "=== Full Workflow Completed ==="
