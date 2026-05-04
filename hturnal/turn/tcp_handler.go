package turn

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
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

		clientIP := getClientIP(r)

		clientPort, clientID, err := globalIPPortPool.AllocateClientPort(clientIP)
		if err != nil {
			http.Error(w, err.Error(), http.StatusServiceUnavailable)
			return
		}

		relayPort, err := globalRelayPortPool.Allocate()
		if err != nil {
			globalIPPortPool.ReleaseClientPort(clientIP, clientPort)
			http.Error(w, err.Error(), http.StatusServiceUnavailable)
			return
		}

		if err := store.DeleteAllocationsByClientID(clientID); err != nil {
			globalIPPortPool.ReleaseClientPort(clientIP, clientPort)
			globalRelayPortPool.Release(relayPort)
			http.Error(w, "Failed to cleanup old allocations", http.StatusInternalServerError)
			return
		}

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

		// Read body
		body, err := io.ReadAll(r.Body)
		if err != nil {
			log.Printf("[TCPDial] Read body error: %v", err)
			http.Error(w, "Invalid body", http.StatusBadRequest)
			return
		}
		log.Printf("[TCPDial] Raw body: %s", string(body))

		var req TCPDialRequest
		if err := json.Unmarshal(body, &req); err != nil {
			log.Printf("[TCPDial] JSON decode error: %v, body: %s", err, string(body))
			http.Error(w, "Invalid JSON", http.StatusBadRequest)
			return
		}

		log.Printf("[TCPDial] RelayID=%s, PeerID=%s", req.RelayID, req.PeerID)

		if req.RelayID == "" || req.PeerID == "" {
			http.Error(w, "Missing relay_id or peer_id", http.StatusBadRequest)
			return
		}

		// Get caller's allocation
		callerAlloc, err := store.GetAllocation(req.RelayID)
		if err != nil || callerAlloc == nil {
			http.Error(w, "Relay not found", http.StatusNotFound)
			return
		}

		// Get peer's allocation
		peerAlloc, err := store.GetAllocationByClientID(req.PeerID)
		if err != nil || peerAlloc == nil {
			http.Error(w, "Peer not found", http.StatusNotFound)
			return
		}

		// Check permission
		callerAlloc.Mu.RLock()
		hasPermission := callerAlloc.Permissions[req.PeerID]
		callerAlloc.Mu.RUnlock()

		// Auto-permit for demo (same-IP clients)
		if !hasPermission {
			callerAlloc.Mu.Lock()
			callerAlloc.Permissions[req.PeerID] = true
			callerAlloc.Mu.Unlock()
			log.Printf("[TCPDial] Auto-permitted peer %s for demo", req.PeerID)
			hasPermission = true
		}

		if !hasPermission {
			http.Error(w, "Peer not permitted", http.StatusForbidden)
			return
		}

		// Create TCP connection
		connID := fmt.Sprintf("conn_%d", time.Now().UnixNano())
		tcpConn := &storage.TCPConnection{
			ConnID:    connID,
			OwnerID:   callerAlloc.ClientID,  // The one who initiated the connection
			PeerID:    req.PeerID,
			OwnerPort:  callerAlloc.RelayPort, // Owner's relay port (for URL routing)
			Incoming:  make(chan *storage.PortData, 65535), // Peer→Owner
			Outgoing:  make(chan *storage.PortData, 65535), // Owner→Peer
			CreatedAt: time.Now(),
		}

		// Store connection in both allocations (under lock)
		peerAlloc.Mu.Lock()
		if peerAlloc.PendingConnections == nil {
			peerAlloc.PendingConnections = make(chan *storage.TCPConnection, 1024)
		}
		if peerAlloc.Connections == nil {
			peerAlloc.Connections = make(map[string]*storage.TCPConnection)
		}
		peerAlloc.Connections[connID] = tcpConn
		peerAlloc.Mu.Unlock()

		callerAlloc.Mu.Lock()
		if callerAlloc.Connections == nil {
			callerAlloc.Connections = make(map[string]*storage.TCPConnection)
		}
		callerAlloc.Connections[connID] = tcpConn
		callerAlloc.Mu.Unlock()

		// Push to pending queue for Accept (with timeout to avoid blocking)
		pushTimeout := time.After(2 * time.Second)
		select {
		case peerAlloc.PendingConnections <- tcpConn:
			log.Printf("[TCPDial] Connection %s pushed to peer %s pending queue", connID, req.PeerID)
		case <-pushTimeout:
			log.Printf("[TCPDial] Timeout pushing to pending queue for peer %s", req.PeerID)
			http.Error(w, "Peer's pending queue full or blocked", http.StatusServiceUnavailable)
			return
		}

		log.Printf("[TCPDial] Connection established: connID=%s, owner=%s (port %d), peer=%s",
			connID, callerAlloc.ClientID, callerAlloc.RelayPort, req.PeerID)

		resp := TCPDialResponse{
			ConnectionID: connID,
		}

		log.Printf("[TCPDial] Connection %s created: caller=%s, peer=%s", connID, callerAlloc.ClientID, req.PeerID)

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

		alloc, err := store.GetAllocation(relayID)
		if err != nil || alloc == nil {
			http.Error(w, "Relay not found", http.StatusNotFound)
			return
		}

		// Long-poll for incoming connection (30 second timeout)
		timeout := 30 * time.Second
		deadline := time.After(timeout)

		log.Printf("[TCPAccept] Waiting for incoming connection, relayID=%s", relayID)

		for {
			alloc.Mu.Lock()
			pendingChan := alloc.PendingConnections
			alloc.Mu.Unlock()

			if pendingChan != nil {
				// Block on channel read with timeout
				select {
				case tcpConn := <-pendingChan:
					if tcpConn != nil {
						log.Printf("[TCPAccept] Accepted connection %s from %s", tcpConn.ConnID, tcpConn.PeerID)
						resp := TCPAcceptResponse{
							ConnectionID: tcpConn.ConnID,
							PeerID:       tcpConn.PeerID,
						}
						w.Header().Set("Content-Type", "application/json")
						json.NewEncoder(w).Encode(resp)
						return
					}
				case <-deadline:
					// Timeout
					log.Printf("[TCPAccept] Timeout waiting for connection, relayID=%s", relayID)
					http.Error(w, "Timeout waiting for connection", http.StatusGatewayTimeout)
					return
				case <-time.After(100 * time.Millisecond):
					// Short poll interval, continue waiting
				}
			} else {
				// Wait for pendingChan to be initialized
				select {
				case <-time.After(100 * time.Millisecond):
					// Continue loop
				case <-deadline:
					log.Printf("[TCPAccept] Timeout waiting for connection, relayID=%s", relayID)
					http.Error(w, "Timeout waiting for connection", http.StatusGatewayTimeout)
					return
				}
			}
		}
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

		clientID := r.Header.Get("X-Hturnal-Client-ID")
		if clientID == "" {
			http.Error(w, "Missing X-Hturnal-Client-ID", http.StatusBadRequest)
			return
		}

		alloc, err := store.GetAllocationByPort(port)
		if err != nil || alloc == nil {
			http.Error(w, "Port not found", http.StatusNotFound)
			return
		}

		// Find TCP connection by connID
		alloc.Mu.Lock()
		var tcpConn *storage.TCPConnection
		if alloc.Connections != nil {
			tcpConn = alloc.Connections[connID]
		}
		alloc.Mu.Unlock()

		if tcpConn == nil {
			http.Error(w, "Connection not found", http.StatusNotFound)
			return
		}

		log.Printf("[TCPRelay] port=%d, connID=%s, clientID=%s, alloc.ClientID=%s, method=%s",
			port, connID, clientID, alloc.ClientID, r.Method)

		// Determine if this client is the owner (the one who initiated the TCP connection)
		isOwner := (clientID == tcpConn.OwnerID)

		switch r.Method {
		case "POST":
			data, err := io.ReadAll(io.LimitReader(r.Body, 65536))
			if err != nil || len(data) > 65535 {
				http.Error(w, "Invalid data", http.StatusBadRequest)
				return
			}

			// Route data to the OTHER side's channel
			// If owner sends, data goes to peer's Incoming (which is tcpConn.Outgoing from peer's view)
			// Actually, let's simplify: tcpConn has two channels:
			// - OwnerToPeer: owner sends, peer receives from this
			// - PeerToOwner: peer sends, owner receives from this
			//
			// For simplicity, we use:
			// - tcpConn.Outgoing: data FROM owner TO peer
			// - tcpConn.Incoming: data FROM peer TO owner

			var targetChan chan *storage.PortData
			if isOwner {
				targetChan = tcpConn.Outgoing // Owner→Peer
			} else {
				targetChan = tcpConn.Incoming // Peer→Owner
			}

			portData := &storage.PortData{
				From:      clientID,
				Data:      data,
				Timestamp: time.Now(),
			}

			select {
			case targetChan <- portData:
				log.Printf("[TCPRelay] Data sent to conn %s, len=%d, from=%s (isOwner=%v)",
					connID, len(data), clientID, isOwner)
				w.WriteHeader(http.StatusOK)
			default:
				log.Printf("[TCPRelay] Queue full for conn %s", connID)
				http.Error(w, "Queue full", http.StatusServiceUnavailable)
			}

		case "GET":
			timeout := 30
			if t := r.URL.Query().Get("timeout"); t != "" {
				fmt.Sscanf(t, "%d", &timeout)
			}

			deadline := time.Now().Add(time.Duration(timeout) * time.Second)

			// Read from the channel that has data FOR this client
			var sourceChan chan *storage.PortData
			if isOwner {
				sourceChan = tcpConn.Incoming // Owner reads data from Peer
			} else {
				sourceChan = tcpConn.Outgoing // Peer reads data from Owner
			}

			for time.Now().Before(deadline) {
				select {
				case portData := <-sourceChan:
					if portData != nil {
						log.Printf("[TCPRelay] Data received from conn %s, len=%d, from=%s (isOwner=%v)",
							connID, len(portData.Data), portData.From, isOwner)
						w.Header().Set("Content-Type", "application/octet-stream")
						w.Header().Set("X-Hturnal-From", portData.From)
						w.Header().Set("X-Hturnal-Timestamp", fmt.Sprintf("%d", portData.Timestamp.Unix()))
						w.Write(portData.Data)
						return
					}
				default:
					time.Sleep(100 * time.Millisecond)
				}
			}
			log.Printf("[TCPRelay] Timeout waiting for data, connID=%s, clientID=%s", connID, clientID)
			w.WriteHeader(http.StatusNoContent)

		default:
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		}
	}
}
