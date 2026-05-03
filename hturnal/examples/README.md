# cfworker curl Examples

This directory contains example scripts demonstrating how to use the hturnal HTTP STUN/TURN server via curl.

## Prerequisites

- `curl` installed
- `jq` installed (optional, for pretty JSON output)
- cfworker running locally: `npx wrangler dev --port 8181`

## Quick Start

1. Start the cfworker server (Terminal 1):
   ```bash
   cd /home/yatseni/ttt/cfworker
   npx wrangler dev --port 8181
   ```

2. Run examples (Terminal 2):
   ```bash
   cd /home/yatseni/ttt/cfworker/examples
   
   # Run individual examples
   ./01_stun_binding.sh
   ./02_stun_nat_check.sh
   ./03_turn_allocate.sh
   
   # After allocating a relay, set RELAY_ID and test send/receive
   source ./03_turn_allocate.sh
   ./04_turn_send_receive.sh
   
   # Test stream functionality
   ./06_stream_example.sh
   
   # Get discovery server list
   ./07_discovery.sh
   
   # Run full workflow demo
   ./08_full_workflow.sh
   ```

## Example Scripts

| Script | Description |
|--------|-------------|
| `01_stun_binding.sh` | Get public address via STUN binding |
| `02_stun_nat_check.sh` | Detect NAT type |
| `03_turn_allocate.sh` | Allocate a TURN relay (saves RELAY_ID) |
| `04_turn_send_receive.sh` | Send and receive messages via TURN relay |
| `05_turn_refresh_deallocate.sh` | Refresh allocation and deallocate |
| `06_stream_example.sh` | Full stream workflow (start, send, receive, end) |
| `07_discovery.sh` | Get server list from discovery endpoint |
| `08_full_workflow.sh` | Complete workflow: STUN → TURN → Stream |

## Environment Variables

Some scripts use environment variables to pass data between examples:

- `RELAY_ID`: Set by `03_turn_allocate.sh`, used by send/receive/refresh/deallocate scripts
- `STREAM_ID`: Set by `06_stream_example.sh`, used for stream operations

## Manual curl Commands

If you prefer to run curl commands directly:

### STUN Binding
```bash
curl -s -X POST -H "Content-Type: application/json" \
  -d '{"client_id":"test1"}' \
  http://localhost:8181/stun/binding
```

### TURN Allocate
```bash
curl -s -X POST -H "Content-Type: application/json" \
  -d '{"client_id":"test1"}' \
  http://localhost:8181/turn/allocate
```

### TURN Send
```bash
curl -s -X POST -H "Content-Type: application/json" \
  -d '{"relay_id":"relay_xxx","peer_id":"peer1","data":"SGVsbG8="}' \
  http://localhost:8181/turn/send
```

### TURN Receive (long-poll)
```bash
curl -s "http://localhost:8181/turn/receive?relay_id=relay_xxx&timeout=5"
```

### Discovery
```bash
curl -s http://localhost:8181/discovery/servers
```

## Notes

- All endpoints expect JSON requests with `Content-Type: application/json`
- Base64 encoding is used for binary data (e.g., `echo -n "Hello" | base64`)
- Long-polling endpoints (`/turn/receive`, `/turn/stream/receive`) wait up to 10 seconds
- Replace `http://localhost:8181` with your actual server URL when deployed
