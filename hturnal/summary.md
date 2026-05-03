# hturnal - HTTP STUN/TURN Server Implementation Plan

## Project Overview
A Go implementation of STUN/TURN protocols over HTTP, providing NAT traversal and relay services for P2P networks without standard UDP/TCP STUN/TURN protocols.

**Module**: `github.com/kitech/touse/hturnal`  
**Go Version**: 1.18 (compatible)  
**Total Files**: 16

---

## Key Design Decisions

| Decision | Choice | Notes |
|----------|--------|-------|
| **HTTP Router** | Standard `net/http` | No third-party packages (gorilla/mux removed) |
| **Package Structure** | No `internal` package | All sub-packages at top level |
| **Client Struct** | Unified `Client` | Merged STUN/TURN/Stream methods |
| **Default Port** | 8181 | Priority: `-port` flag > `PORT` env > default |
| **Log** | Built-in `log` package | Default: `Lshortfile\|Ldate\|Ltime`, configurable |
| **Storage** | Build tags switchable | `memory` (default), `redis`, `sqlite` |
| **Binary Data** | Standard base64 | In JSON `data` field |
| **Authentication** | Open access | No auth (simplify initial implementation) |
| **NAT Detection** | Single IP mode | Returns `"nat_type": "Unknown (single IP)"` |
| **Configuration** | Env vars + flags | `PORT`, `STORAGE_TYPE`, etc. |

---

## Project Structure
```
/home/yatseni/ttt/
├── cmd/
│   ├── server/
│   │   └── main.go          # Server entry point
│   └── client/
│       └── main.go          # Client example
├── stun/                    # STUN server handlers
│   ├── handler.go
│   └── types.go
├── turn/                    # TURN server handlers
│   ├── handler.go
│   ├── stream.go
│   └── types.go
├── discovery/               # Server discovery endpoint
│   └── handler.go
├── storage/                 # Storage layer (build tags)
│   ├── types.go           # Storage interface + common types
│   ├── memory.go          # In-memory storage (tags: !redis,!sqlite)
│   ├── redis.go           # Redis storage (tags: redis)
│   └── sqlite.go          # SQLite storage (tags: sqlite)
├── server/                  # HTTP server setup
│   └── server.go
├── client/                  # Client library
│   ├── client.go         # Unified Client struct + all methods
│   └── types.go         # Request/response types
├── cfworker/               # Cloudflare Worker (TypeScript port)
│   ├── src/
│   │   ├── index.ts          # Worker entry point
│   │   ├── types.ts         # TypeScript types
│   │   ├── storage.ts       # Memory + Durable Object storage
│   │   ├── stun.ts          # STUN handlers
│   │   ├── turn.ts          # TURN/Stream handlers
│   │   ├── discovery.ts     # Discovery endpoint
│   │   ├── utils.ts        # Utility functions
│   │   └── durable_object.ts # Durable Object (SQLite backend)
│   ├── examples/            # curl example scripts
│   │   ├── 01_stun_binding.sh
│   │   ├── 02_stun_nat_check.sh
│   │   ├── 03_turn_allocate.sh
│   │   ├── 04_turn_send_receive.sh
│   │   ├── 05_turn_refresh_deallocate.sh
│   │   ├── 06_stream_example.sh
│   │   ├── 07_discovery.sh
│   │   ├── 08_full_workflow.sh
│   │   └── README.md
│   ├── package.json
│   ├── tsconfig.json
│   ├── wrangler.toml
│   └── README.md
├── go.mod                   # Module: github.com/kitech/touse/hturnal
└── summary.md
```

---

## Endpoint Design

### STUN Endpoints
| Endpoint | Method | Function |
|----------|--------|----------|
| `/stun/binding` | POST | Return client's public IP:port |
| `/stun/nat-check` | POST | Full NAT type detection (single IP mode) |

### TURN Endpoints
| Endpoint | Method | Function |
|----------|--------|----------|
| `/turn/allocate` | POST | Allocate relay resource |
| `/turn/permission` | POST | Add peer permissions |
| `/turn/send` | POST | Send data to peer (base64 in JSON) |
| `/turn/receive` | GET | Receive data (long-poll with `timeout` param) |
| `/turn/refresh` | POST | Refresh allocation TTL |
| `/turn/deallocate` | POST | Release relay resources |

### TURN Stream Endpoints
| Endpoint | Method | Function |
|----------|--------|----------|
| `/turn/stream/start` | POST | Initialize binary stream |
| `/turn/stream/send` | POST | Send chunk with `stream_id` and `chunk_seq` |
| `/turn/stream/receive` | GET | Retrieve chunks (long-poll) |
| `/turn/stream/end` | POST | Signal stream end |

### Discovery Endpoint
| Endpoint | Method | Function |
|----------|--------|----------|
| `/discovery/servers` | GET | Return available server list |

---

## Storage Interface

### Go Storage Interface
```go
// storage/types.go
type Storage interface {
    // STUN
    SaveSTUNSession(id string, session *STUNSession) error
    GetSTUNSession(id string) (*STUNSession, error)
    
    // TURN
    SaveAllocation(relayID string, alloc *TURNAllocation) error
    GetAllocation(relayID string) (*TURNAllocation, error)
    DeleteAllocation(relayID string) error
    
    // Stream
    SaveStream(streamID string, stream *StreamState) error
    GetStream(streamID string) (*StreamState, error)
    
    // Cleanup
    StartCleanup(interval time.Duration)
}
```

### Build Tags for Storage
| File | Build Tag | Description |
|------|------------|-------------|
| `memory.go` | `//go:build !redis,!sqlite` | Default in-memory storage |
| `redis.go` | `//go:build redis` | Redis-backed storage |
| `sqlite.go` | `//go:build sqlite` | SQLite-backed storage |

### Cloudflare Worker Storage
- **MemoryStorage**: In-memory Map (default for local dev)
- **DurableObjectStorage**: SQLite-backed Durable Object (production, free plan)
- **Switching**: Via `STORAGE_BACKEND` env var in `wrangler.toml`

---

## Port Configuration
Priority (highest to lowest):
1. **Command-line flag**: `-port 9000`
2. **Environment variable**: `PORT=9000`
3. **Default**: `8181`

---

## Log Configuration
- **Package**: Built-in `log`
- **Default flags**: `log.Lshortfile | log.Ldate | log.Ltime` (value: 11)
- **Configurable via**:
  - Command-line flag: `-log-flags 11`
  - Method call: `log.SetFlags(flags)`

---

## Client Package
Unified `Client` struct with all methods:

```go
// client/client.go
type Client struct {
    serverURL string
    httpClient *http.Client
    relayID   string
}

func NewClient(serverURL string) *Client { ... }

// STUN methods
func (c *Client) GetPublicAddress(clientID string) (*STUNBindingResponse, error)
func (c *Client) CheckNATType(clientID string) (*STUNNATCheckResponse, error)

// TURN methods
func (c *Client) Allocate(clientID string) (*TURNAllocateResponse, error)
func (c *Client) SendToPeer(peerID string, data []byte) error
func (c *Client) Receive(timeout int) ([]TURNMessage, error)

// Stream methods
func (c *Client) StartStream(peerID string) (*StreamStartResponse, error)
```

**Compatibility**: Go client works with both Go server and Cloudflare Worker (same JSON API).

---

## Compilation Examples
```bash
# 1. Default (in-memory storage)
go build -o server ./cmd/server

# 2. Redis storage
go build -tags redis -o server ./cmd/server

# 3. SQLite storage
go build -tags sqlite -o server ./cmd/server

# 4. Client
go build -o client ./cmd/client
```

---

## Dependencies (go.mod)
```go
module github.com/kitech/touse/hturnal

go 1.18

require (
    github.com/google/uuid v1.6.0
    github.com/go-redis/redis/v8 v8.11.5  // redis tag
    github.com/mattn/go-sqlite3 v2.0.3+incompatible  // sqlite tag (needs CGO)
)
```

---

## Request/Response Format (JSON)

### STUN Binding
```json
// POST /stun/binding
{"client_id": "node_a"}
→ {"mapped_address": "203.0.113.5:54321", "xored": false, "source": "http-stun"}
```

### TURN Allocate
```json
// POST /turn/allocate
{"client_id": "node_a"}
→ {"relay_id": "relay_123", "relay_address": "203.0.113.5:12345", "lifetime": 600}
```

### TURN Send/Receive (base64)
```json
// POST /turn/send
{"relay_id": "relay_123", "peer_id": "node_b", "data": "SGVsbG8=", "ttl": 300}

// GET /turn/receive?relay_id=relay_123&timeout=30
→ {"messages": [{"from": "node_a", "data": "SGVsbG8=", "timestamp": 1746000000}]}
```

### Stream Chunk
```json
// POST /turn/stream/send
{"stream_id": "stream_456", "chunk_seq": 0, "data": "base64chunk...", "hash": "optional"}

// GET /turn/stream/receive?stream_id=stream_456&timeout=30
→ {"chunks": [{"seq": 0, "data": "base64chunk..."}], "stream_complete": false}
```

---

## Cloudflare Worker (cfworker/)

### Features
- **Language**: TypeScript
- **Runtime**: Cloudflare Workers (V8 isolate)
- **Storage**: Memory (default) or Durable Objects (SQLite, free plan)
- **CORS**: Enabled (`Access-Control-Allow-Origin: *`)
- **Long-polling**: Max 10 seconds (Worker CPU limit)

### Configuration
```toml
# wrangler.toml
name = "hturnal-worker"
main = "src/index.ts"
compatibility_date = "2025-07-18"

[durable_objects]
bindings = [
  { name = "HTURNAL_DO", class_name = "HturnalDurableObject" }
]

[vars]
STORAGE_BACKEND = "memory"  # or "durable_object"

[triggers]
crons = ["*/1 * * * *"]
```

### curl Examples
All endpoints can be tested with curl (see `cfworker/examples/`):
```bash
# STUN Binding
curl -s -X POST -H "Content-Type: application/json" \
  -d '{"client_id":"test1"}' http://localhost:8181/stun/binding

# TURN Allocate
curl -s -X POST -H "Content-Type: application/json" \
  -d '{"client_id":"test1"}' http://localhost:8181/turn/allocate

# Discovery
curl -s http://localhost:8181/discovery/servers
```

---

## Implementation Order
1. `go.mod` + `storage/types.go` + `storage/memory.go`
2. `stun/types.go` + `stun/handler.go`
3. `turn/types.go` + `turn/handler.go` + `turn/stream.go`
4. `discovery/handler.go`
5. `server/server.go`
6. `client/types.go` + `client/client.go`
7. `cmd/server/main.go` + `cmd/client/main.go`
8. `storage/redis.go` + `storage/sqlite.go` (optional, with build tags)
9. **cfworker/** - TypeScript port (completed)

---

## Notes
- All binary data encoded in standard base64 within JSON
- Long-polling for `/turn/receive` and `/turn/stream/receive` (max 30s in Go, 10s in Worker)
- Go memory storage uses `sync.RWMutex` for thread safety
- Worker memory storage is per-isolate (no cross-isolate sharing)
- Cleanup goroutine runs every 1 minute to remove expired data (Go)
- Worker uses cron trigger for cleanup (configured in `wrangler.toml`)
- Server returns CORS headers for cross-origin requests
- Single IP NAT detection returns limited results (no multi-IP tests)
- **Go client is fully compatible with cfworker** (same JSON API)

---

## Progress Status

### ✅ Completed
1. Go hturnal server implementation (all endpoints)
2. Go client library + example
3. cfworker TypeScript implementation (all endpoints)
4. Durable Object storage backend (SQLite, free plan)
5. curl examples (8 scripts + README)
6. Memory/Durable Object storage switching

### ⚠️ Pending
1. Test full workflow with curl examples
2. Fix potential syntax errors in TypeScript code
3. Deploy cfworker to Cloudflare (test with `wrangler deploy`)
4. Update Go client to use Cloudflare Worker URL

### 🔴 Known Issues
1. `src/durable_object.ts`: `1000` typo (written as `1000` in some places)
2. Missing commas in `Map.set()` calls (may cause syntax errors)
3. Need to verify all TypeScript files compile without errors
