package turn

import (
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/kitech/touse/hturnal/storage"
)

// NewTCPAllocateHandler handles TCP allocation
func NewTCPAllocateHandler(store storage.Storage) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != "POST" {
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
			return
		}

		// Similar to UDP allocate but for TCP
		clientIP := getClientIP(r)

		// Allocate client port from per-IP pool
		clientPort, clientID, err := globalIPPortPool.AllocateClientPort(clientIP)
		if err != nil {
			http.Error(w, err.Error(), http.StatusServiceUnavailable)
			return
		}

		// Allocate relay port from global pool
		relayPort, err := globalRelayPortPool.Allocate()
		if err != nil {
			globalIPPortPool.ReleaseClientPort(clientIP, clientPort)
			http.Error(w, err.Error(), http.StatusServiceUnavailable)
			return
		}

		// Clean up old allocations for this client
		if err := store.DeleteAllocationsByClientID(clientID); err != nil {
			globalIPPortPool.ReleaseClientPort(clientIP, clientPort)
			globalRelayPortPool.Release(relayPort)
			http.Error(w, "Failed to cleanup old allocations", http.StatusInternalServerError)
			return
		}

		// Generate internal relay ID
		relayID := generateID()
		alloc := &storage.TURNAllocation{
			RelayID:       relayID,
			ClientID:      clientID,
			RelayPort:     relayPort,
			Permissions:   make(map[string]bool),
			IncomingQueue: make(chan *storage.PortData, 65535),
			OutgoingQueue: make(chan *storage.PortData, 65535),
			Lifetime:      10 * time.Minute,
			ExpiresAt:     time.Now().Add(10 * time.Minute),
		}

		if err := store.SaveAllocation(relayID, alloc); err != nil {
			globalIPPortPool.ReleaseClientPort(clientIP, clientPort)
			globalRelayPortPool.Release(relayPort)
			http.Error(w, "Failed to save allocation", http.StatusInternalServerError)
			return
		}

		resp := AllocateResponse{
			ClientID:  clientID,
			RelayID:   relayID,
			RelayPort: relayPort,
			RelayPath:  fmt.Sprintf("/turn/tcp/%d", relayPort),
			Lifetime:  int(alloc.Lifetime.Seconds()),
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(resp)
	}
}

// NewTCPDialHandler handles TCP dial (create connection to peer)
func NewTCPDialHandler(store storage.Storage) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != "POST" {
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
			return
		}

		var req TCPDialRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, "Invalid JSON", http.StatusBadRequest)
			return
		}

		if req.RelayID == "" || req.PeerID == "" {
			http.Error(w, "Missing relay_id or peer_id", http.StatusBadRequest)
			return
		}

		// Find allocation
		alloc, err := store.GetAllocation(req.RelayID)
		if err != nil || alloc == nil {
			http.Error(w, "Relay not found", http.StatusNotFound)
			return
		}

		// Check permission
		alloc.Mu.RLock()
		hasPermission := alloc.Permissions[req.PeerID]
		alloc.Mu.RUnlock()

		if !hasPermission {
			http.Error(w, "Peer not permitted", http.StatusForbidden)
			return
		}

		// Generate connection ID
		connID := fmt.Sprintf("conn_%d", time.Now().UnixNano())

		// Store connection info (in real implementation, would create actual TCP connection)
		// For now, just return the connection ID
		resp := TCPDialResponse{
			ConnectionID: connID,
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(resp)
	}
}

// NewTCPAcceptHandler handles TCP accept (long-poll for incoming connections)
func NewTCPAcceptHandler(store storage.Storage) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != "GET" {
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
			return
		}

		relayID := r.URL.Query().Get("relay_id")
		if relayID == "" {
			http.Error(w, "Missing relay_id", http.StatusBadRequest)
			return
		}

		// Find allocation
		alloc, err := store.GetAllocation(relayID)
		if err != nil || alloc == nil {
			http.Error(w, "Relay not found", http.StatusNotFound)
			return
		}

		// Long-poll for incoming connection (simplified: return immediately)
		// In real implementation, would wait for actual incoming TCP connections
		resp := TCPAcceptResponse{
			ConnectionID: "conn_example",
			PeerID:      "peer_example",
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(resp)
	}
}

// NewTCPDeallocateHandler handles TCP deallocation
func NewTCPDeallocateHandler(store storage.Storage) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != "POST" {
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
			return
		}

		var req TCPDeallocateRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, "Invalid JSON", http.StatusBadRequest)
			return
		}

		if err := store.DeleteAllocation(req.RelayID); err != nil {
			http.Error(w, "Failed to deallocate", http.StatusInternalServerError)
			return
		}

		resp := TCPDeallocateResponse{Status: "deallocated"}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(resp)
	}
}

// NewTCPRelayHandler handles TCP relay data plane
// POST /relay/tcp/{port}/{conn_id} - send data
// GET /relay/tcp/{port}/{conn_id} - receive data (long-poll)
func NewTCPRelayHandler(store storage.Storage) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		// Parse path: /relay/tcp/{port}/{conn_id}
		path := r.URL.Path
		parts := strings.Split(path, "/")
		if len(parts) < 5 {
			http.Error(w, "Invalid path", http.StatusBadRequest)
			return
		}

		portStr := parts[3]
		connID := parts[4]

		port := 0
		fmt.Sscanf(portStr, "%d", &port)
		if port == 0 || connID == "" {
			http.Error(w, "Invalid port or connection ID", http.StatusBadRequest)
			return
		}

		switch r.Method {
		case "POST":
			// Send data (simplified: just return OK)
			w.WriteHeader(http.StatusOK)
		case "GET":
			// Receive data (simplified: return no content)
			w.WriteHeader(http.StatusNoContent)
		default:
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		}
	}
}
