# hturnal - HTTP STUN/TURN Server Implementation Plan

## Project Overview
A Go implementation of STUN/TURN protocols over HTTP, providing NAT traversal and relay services for P2P networks without standard UDP/TCP STUN/TURN protocols.

**Module**: `github.com/kitech/touse/hturnal`  
**Go Version**: 1.20+  
**Total Files**: 18

---

## Key Design Decisions

| Decision | Choice | Notes |
|----------|--------|-------|
| **HTTP Router** | Standard `net/http` | No third-party packages (gorilla/mux removed) |
| **Package Structure** | No `internal` package | All sub-packages at top level |
| **Client ID Allocation** | Server-allocated | Format `"ip:port"`, from dual port pools |
| **Port Pool Design** | Dual pools | Per-IP pool (1-1024) + Global pool (1-65535) |
| **Data Plane** | Pseudo-port `/relay/{port}` | HTTP long-polling with `X-Hturnal-` headers |
| **PacketConn** | `httpPacketConn` | Implements `net.PacketConn` for pion/turn compatibility |
| **Queue Implementation** | Go channel | Replaced `adrianbrad/queue` (simplify design) |
| **Default Port** | 8181 | Priority: `-port` flag > `PORT` env > default |
| **Log** | Built-in `log` package | Default: `Lshortfile\|Ldate\|Ltime`, configurable |
| **Storage** | Build tags switchable | `memory` (default), `redis`, `sqlite` |
| **Binary Data** | Raw binary + HTTP headers | `application/octet-stream` + `X-Hturnal-From` header |
| **Authentication** | Reserved fields | Username/Password in ClientConfig for future use |
| **NAT Detection** | Single IP mode | Returns `"nat_type": "Unknown (single IP)"` |
| **Configuration** | Env vars + flags | `PORT`, `STORAGE_TYPE`, etc. |

---

## Project Structure
```
/home/gzleo/aprog/touse/hturnal/
├── cmd/
│   ├── server/
│   │   └── main.go          # Server entry point
│   └── client/
│       └── main.go          # Client example (updated for new API)
├── stun/                    # STUN server handlers
│   ├── handler.go
│   └── types.go
├── turn/                    # TURN server handlers
│   ├── handler.go          # Allocate with dual port pools
│   ├── relay.go            # NEW: /relay/{port} pseudo-port data plane
│   ├── portpool.go         # NEW: Dual port pool management
│   ├── stream.go
│   └── types.go
├── discovery/               # Server discovery endpoint
│   └── handler.go
├── storage/                 # Storage layer (build tags)
│   ├── types.go           # Storage interface + common types
│   ├── memory.go          # In-memory storage (tags: !redis,!sqlite)
│   ├── redis.go           # Redis storage (tags: redis)
│   └── sqlite.go          # SQLite storage (tags: sqlite)
├── client/                  # Client library
│   ├── client.go         # Allocate() returns net.PacketConn
│   ├── packetconn.go      # NEW: httpPacketConn implementation
│   └── types.go         # Request/response types
├── mydemo/                 # Demo with two nodes
│   └── main.go           # Updated for new API
├── cfworker/               # Cloudflare Worker (TypeScript port)
│   └── ... (unchanged)
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
| `/turn/allocate` | POST | Allocate relay (server-assigned clientID + relayPort) |
| `/turn/permission` | POST | Add peer permissions |
| `/turn/send` | POST | Send data to peer (base64 in JSON) |
| `/turn/receive` | GET | Receive data (long-poll with `timeout` param) |
| `/turn/refresh` | POST | Refresh allocation TTL |
| `/turn/deallocate` | POST | Release relay resources |

### TURN Relay Endpoint (NEW - Phase 3)
| Endpoint | Method | Function |
|----------|--------|----------|
| `/relay/{port}` | POST | Send raw binary data (sets `X-Hturnal-Client-ID`, `X-Hturnal-Xor-Peer-Address`) |
| `/relay/{port}` | GET | Receive data (long-poll, returns raw binary + `X-Hturnal-From` header) |

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
    GetAllocationByClientID(clientID string) (*TURNAllocation, error)
    GetAllocationByPort(port int) (*TURNAllocation, error)  // NEW
    DeleteAllocation(relayID string) error
    DeleteAllocationsByClientID(clientID string) error
    
    // Stream
    SaveStream(streamID string, stream *StreamState) error
    GetStream(streamID string) (*StreamState, error)
    
    // Cleanup
    StartCleanup(interval time.Duration)
}
```

### TURNAllocation Structure (Updated)
```go
type TURNAllocation struct {
    RelayID       string
    ClientID      string                    // Server-allocated "ip:port"
    RelayPort     int                       // Pseudo-port for /relay/{port}
    Permissions   map[string]bool
    MessageQueues map[string][]*Message    // Legacy (for /turn/receive)
    IncomingQueue chan *PortData           // Peer→Owner (for /relay/{port})
    OutgoingQueue chan *PortData           // Owner→Peer (for /relay/{port})
    Lifetime      time.Duration
    ExpiresAt     time.Time
    Mu            sync.RWMutex
}
```

### Build Tags for Storage
| File | Build Tag | Description |
|------|------------|-------------|
| `memory.go` | `//go:build !redis,!sqlite` | Default in-memory storage |
| `redis.go` | `//go:build redis` | Redis-backed storage |
| `sqlite.go` | `//go:build sqlite` | SQLite-backed storage |

---

## Port Pool Design (NEW - Phase 3)

### Dual Port Pools
1. **Per-IP Port Pool** (1-1024)
   - Key: Client IP address
   - Value: Allocated ports (max 1024 per IP)
   - Used for: Generating `clientID` (format: `"ip:port"`)

2. **Global Relay Port Pool** (1-65535)
   - Shared across all clients
   - Used for: `relayPort` (pseudo-port for `/relay/{port}`)

### Client IP Detection Priority
1. `X-Forwarded-For` header
2. `X-Real-IP` header
3. `RemoteAddr` (parse IP part)

---

## Client Package (Updated - Phase 4)

### API Compatibility with pion/turn
```go
// client/client.go
type Client struct {
    config     *ClientConfig
    httpClient *http.Client
    clientID   string    // Server-allocated "ip:port"
    relayPort  int       // Pseudo-port for data plane
    conn       net.PacketConn // httpPacketConn
}

func NewClient(config *ClientConfig) (*Client, error)

// STUN methods
func (c *Client) GetPublicAddress(clientID string) (*STUNBindingResponse, error)
func (c *Client) CheckNATType(clientID string) (*STUNNATCheckResponse, error)

// TURN methods (pion/turn compatible)
func (c *Client) Allocate() (net.PacketConn, error)  // Returns httpPacketConn
func (c *Client) Listen() error                       // No-op for HTTP
func (c *Client) Close() error

// Helper methods
func (c *Client) GetClientID() string
func (c *Client) GetRelayPort() int
```

### httpPacketConn Implementation
```go
// client/packetconn.go
type httpPacketConn struct {
    serverURL  string
    relayPort  int
    clientID   string
    httpClient *http.Client
    localAddr  net.Addr
}

func (c *httpPacketConn) ReadFrom(b []byte) (int, net.Addr, error)
func (c *httpPacketConn) WriteTo(b []byte, addr net.Addr) (int, error)
func (c *httpPacketConn) Close() error
func (c *httpPacketConn) LocalAddr() net.Addr
func (c *httpPacketConn) SetDeadline(t time.Time) error
func (c *httpPacketConn) SetReadDeadline(t time.Time) error
func (c *httpPacketConn) SetWriteDeadline(t time.Time) error
```

### HTTP Headers for Data Plane
- `X-Hturnal-Client-ID`: Sender/receiver identifier
- `X-Hturnal-Xor-Peer-Address`: Peer address (XOR-PEER-ADDRESS simulation)
- `X-Hturnal-From`: Sender address (in response)
- `X-Hturnal-Timestamp`: Message timestamp (in response)
- Standard proxy headers (`X-Forwarded-For`, `X-Real-IP`) unchanged

---

## Compilation Examples
```bash
# 1. Default (in-memory storage)
go build -o server ./cmd/server
go build -o client ./cmd/client
go build -o mydemo ./mydemo

# 2. Redis storage
go build -tags redis -o server ./cmd/server

# 3. SQLite storage
go build -tags sqlite -o server ./cmd/server

# 4. Build all
go build ./...
```

---

## Dependencies (go.mod)
```go
module github.com/kitech/touse/hturnal

go 1.20

require (
    github.com/google/uuid v1.6.0
    github.com/go-redis/redis/v8 v8.11.5  // redis tag
    github.com/mattn/go-sqlite3 v2.0.3+incompatible  // sqlite tag (needs CGO)
    // adrianbrad/queue v1.7.0 - removed, using Go channel instead
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

### TURN Allocate (Updated)
```json
// POST /turn/allocate
{"client_id": "node_a"}
→ {
  "client_id": "192.168.1.100:1",
  "relay_id": "relay_123",
  "relay_port": 12345,
  "relay_path": "/relay/12345",
  "lifetime": 600
}
```

### TURN Relay Data Plane (NEW)
```
POST /relay/12345
Headers:
  X-Hturnal-Client-ID: 192.168.1.100:1
  X-Hturnal-Xor-Peer-Address: 192.168.1.101:2
  Content-Type: application/octet-stream
Body: <raw binary data>

GET /relay/12345
Headers:
  X-Hturnal-Client-ID: 192.168.1.100:1
Response:
  Headers:
    X-Hturnal-From: 192.168.1.101:2
    X-Hturnal-Timestamp: 1746000000
  Body: <raw binary data>
```

### TURN Send/Receive (legacy, base64)
```json
// POST /turn/send
{"relay_id": "relay_123", "peer_id": "node_b", "data": "SGVsbG8=", "ttl": 300}

// GET /turn/receive?relay_id=relay_123&timeout=30
→ {"messages": [{"from": "node_a", "data": "SGVsbG8=", "timestamp": 1746000000}]}
```

---

## Implementation Order
1. ✅ `go.mod` + `storage/types.go` + `storage/memory.go`
2. ✅ `stun/types.go` + `stun/handler.go`
3. ✅ `turn/types.go` + `turn/handler.go` + `turn/stream.go`
4. ✅ `discovery/handler.go`
5. ✅ `cmd/server/main.go` + `cmd/client/main.go`
6. ✅ `client/types.go` + `client/client.go`
7. ✅ `turn/portpool.go` (Phase 3: Dual port pools)
8. ✅ `turn/relay.go` (Phase 3: Pseudo-port data plane)
9. ✅ `client/packetconn.go` (Phase 4: httpPacketConn)
10. 🔄 `cmd/server/main.go` (register `/relay/` route)
11. ⏳ Test full workflow

---

## Progress Status

### ✅ Completed
1. Go hturnal server implementation (all endpoints)
2. Dual port pool management (Per-IP + Global)
3. Server-allocated clientID (`"ip:port"` format)
4. Pseudo-port data plane (`/relay/{port}`)
5. Custom HTTP headers (`X-Hturnal-` prefix)
6. Go channel-based queues (replaced adrianbrad/queue)
7. Client API rewrite (`Allocate()` returns `net.PacketConn`)
8. `httpPacketConn` implementation
9. cfworker TypeScript implementation (all endpoints)

### ⚠️ In Progress
1. Fix remaining compilation error: `turn/handler.go` unused import
2. Test compilation: `go build ./...`
3. Start server and test with mydemo

### ⏳ Pending
1. Full workflow test (server + two clients)
2. Verify bidirectional communication via `/relay/{port}`
3. Test port allocation and release
4. Deploy cfworker to Cloudflare (test with `wrangler deploy`)
5. Update Go client to use Cloudflare Worker URL (optional)

### 🔴 Known Issues
1. `turn/handler.go:7:2`: Unused import `"github.com/adrianbrad/queue"` (fixing now)
2. Port release logic needs to be in turn layer (not storage) to avoid circular dependency
3. `WriteTo` addr parameter ignored (pseudo-port implies peer relationship)

---

## Notes
- All binary data in `/relay/{port}` uses raw binary (`application/octet-stream`)
- Metadata passed via HTTP headers (`X-Hturnal-From`, `X-Hturnal-Timestamp`)
- Long-polling for `/relay/{port}` GET and `/turn/receive` (max 30s in Go)
- Go memory storage uses `sync.RWMutex` for thread safety
- Worker memory storage is per-isolate (no cross-isolate sharing)
- Cleanup goroutine runs every 1 minute to remove expired data (Go)
- Server returns CORS headers for cross-origin requests
- Single IP NAT detection returns limited results (no multi-IP tests)
- **Go client is fully compatible with cfworker** (same JSON API for legacy endpoints)
- **New `/relay/{port}` endpoints are Go-only** (cfworker not updated yet)
