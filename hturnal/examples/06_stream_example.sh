#!/bin/bash
# Stream Example
# Demonstrates starting a stream, sending chunks, receiving, and ending

SERVER="http://localhost:8181"

echo "=== Stream Example ==="
echo ""

# Step 1: Start a stream
echo "Step 1: Starting stream between test1 and peer1..."
START_RESP=$(curl -s -X POST \
  -H "Content-Type: application/json" \
  -d '{"client_id":"test1","peer_id":"peer1"}' \
  "${SERVER}/turn/stream/start")

echo "Start Stream Response:"
echo "$START_RESP" | jq '.' 2>/dev/null || echo "$START_RESP"
echo ""

if command -v jq &> /dev/null; then
    STREAM_ID=$(echo "$START_RESP" | jq -r '.stream_id')
    CHUNK_SIZE=$(echo "$START_RESP" | jq -r '.chunk_size')
    TTL=$(echo "$START_RESP" | jq -r '.ttl')
    echo "Stream ID: $STREAM_ID"
    echo "Chunk Size: $CHUNK_SIZE bytes"
    echo "TTL: $TTL seconds"
    echo ""
else
    echo "Please install jq to parse the stream_id automatically"
    echo "Set STREAM_ID manually: export STREAM_ID=\"your_stream_id\""
    exit 1
fi

# Step 2: Send a chunk
echo "Step 2: Sending chunk 0..."
CHUNK_DATA=$(echo -n "Stream chunk data example" | base64)
SEND_RESP=$(curl -s -X POST \
  -H "Content-Type: application/json" \
  -d "{\"stream_id\":\"$STREAM_ID\",\"chunk_seq\":0,\"data\":\"$CHUNK_DATA\"}" \
  "${SERVER}/turn/stream/send")

echo "Send Chunk Response:"
echo "$SEND_RESP" | jq '.' 2>/dev/null || echo "$SEND_RESP"
echo ""

# Step 3: Receive chunks
echo "Step 3: Receiving chunks (waiting up to 5 seconds)..."
RECV_RESP=$(curl -s "${SERVER}/turn/stream/receive?stream_id=${STREAM_ID}&timeout=5")
echo "$RECV_RESP" | jq '.' 2>/dev/null || echo "$RECV_RESP"
echo ""

if command -v jq &> /dev/null; then
    CHUNK_COUNT=$(echo "$RECV_RESP" | jq '.chunks | length')
    echo "Received $CHUNK_COUNT chunk(s)"
    if [ "$CHUNK_COUNT" -gt 0 ]; then
        echo "$RECV_RESP" | jq -r '.chunks[] | "Chunk Seq: \(.seq)\nData (base64): \(.data)\n---"'
    fi
fi

# Step 4: End the stream
echo "Step 4: Ending stream..."
END_RESP=$(curl -s -X POST \
  -H "Content-Type: application/json" \
  -d "{\"stream_id\":\"$STREAM_ID\"}" \
  "${SERVER}/turn/stream/end")

echo "End Stream Response:"
echo "$END_RESP" | jq '.' 2>/dev/null || echo "$END_RESP"
echo ""

echo "Stream example completed."
