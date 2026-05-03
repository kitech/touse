package turn

import (
	"encoding/base64"
	"encoding/json"
	"fmt"
	"github.com/adrianbrad/queue"
	"github.com/kitech/touse/hturnal/storage"
	"net/http"
	"time"
)

// NewAllocateHandler returns handler for TURN allocate
func NewAllocateHandler(store storage.Storage) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != "POST" {
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
			return
		}

		var req AllocateRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, "Invalid JSON", http.StatusBadRequest)
			return
		}

		// 清理该ClientID的旧allocation（防止同名客户端重复注册导致消息丢失）
		if err := store.DeleteAllocationsByClientID(req.ClientID); err != nil {
			http.Error(w, "Failed to cleanup old allocations", http.StatusInternalServerError)
			return
		}

		// Generate relay ID
		relayID := generateID()
		alloc := &storage.TURNAllocation{
			RelayID:       relayID,
			ClientID:      req.ClientID,
			Permissions:   make(map[string]bool),
			MessageQueues: make(map[string]*queue.Blocking[*storage.Message]),
			Lifetime:      10 * time.Minute,
			ExpiresAt:     time.Now().Add(10 * time.Minute),
		}

		if err := store.SaveAllocation(relayID, alloc); err != nil {
			http.Error(w, "Failed to save allocation", http.StatusInternalServerError)
			return
		}

		resp := AllocateResponse{
			RelayID:      relayID,
			RelayAddress: fmt.Sprintf("%s", r.Host), // Simplified
			Lifetime:     int(alloc.Lifetime.Seconds()),
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(resp)
	}
}

// NewPermissionHandler returns handler for adding permissions
func NewPermissionHandler(store storage.Storage) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != "POST" {
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
			return
		}

		var req PermissionRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, "Invalid JSON", http.StatusBadRequest)
			return
		}

		alloc, err := store.GetAllocation(req.RelayID)
		if err != nil || alloc == nil {
			http.Error(w, "Relay not found", http.StatusNotFound)
			return
		}

		alloc.Mu.Lock()
		for _, peerID := range req.PeerIDs {
			alloc.Permissions[peerID] = true
		}
		alloc.Mu.Unlock()

		resp := PermissionResponse{Status: "permissions added"}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(resp)
	}
}

// NewSendHandler returns handler for sending data via relay
func NewSendHandler(store storage.Storage) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != "POST" {
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
			return
		}

		var req SendRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, "Invalid JSON", http.StatusBadRequest)
			return
		}

		// Verify relay exists
		alloc, err := store.GetAllocation(req.RelayID)
		if err != nil || alloc == nil {
			http.Error(w, "Relay not found", http.StatusNotFound)
			return
		}

		// Decode base64 data
		data, err := base64.StdEncoding.DecodeString(req.Data)
		if err != nil {
			http.Error(w, "Invalid base64 data", http.StatusBadRequest)
			return
		}

	// Check permission
	alloc.Mu.RLock()
	hasPermission := alloc.Permissions[req.PeerID]
	alloc.Mu.RUnlock()

	if !hasPermission {
		http.Error(w, "No permission to send to this peer", http.StatusForbidden)
		return
	}

	// Find peer's allocation
	peerAlloc, err := store.GetAllocationByClientID(req.PeerID)
	if err != nil || peerAlloc == nil {
		http.Error(w, "Peer not found", http.StatusNotFound)
		return
	}

	// Store message for peer (in peer's allocation)
	msg := &storage.Message{
		From:      alloc.ClientID,
		Data:      data,
		Timestamp: time.Now(),
	}

	peerAlloc.Mu.Lock()
	q, ok := peerAlloc.MessageQueues[peerAlloc.ClientID]
	if !ok {
		// Create blocking queue with capacity 65535
		q = queue.NewBlocking[*storage.Message](nil, queue.WithCapacity(65535))
		peerAlloc.MessageQueues[peerAlloc.ClientID] = q
	}

	// Offer message, return error if queue is full
	if err := q.Offer(msg); err != nil {
		peerAlloc.Mu.Unlock()
		http.Error(w, "Queue full (max 65535 messages)", http.StatusServiceUnavailable)
		return
	}
	peerAlloc.Mu.Unlock()

		resp := map[string]string{"status": "sent"}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(resp)
	}
}

// NewReceiveHandler returns handler for receiving data (long-poll)
func NewReceiveHandler(store storage.Storage) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != "GET" {
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
			return
		}

		relayID := r.URL.Query().Get("relay_id")
		timeout := 30 // seconds
		maxMessages := 10 // default max messages per request
		if t := r.URL.Query().Get("timeout"); t != "" {
			fmt.Sscanf(t, "%d", &timeout)
		}
		if m := r.URL.Query().Get("max_messages"); m != "" {
			fmt.Sscanf(m, "%d", &maxMessages)
		}
		if maxMessages <= 0 {
			maxMessages = 10
		}

		if relayID == "" {
			http.Error(w, "Missing relay_id parameter", http.StatusBadRequest)
			return
		}

		alloc, err := store.GetAllocation(relayID)
		if err != nil || alloc == nil {
			http.Error(w, "Relay not found", http.StatusNotFound)
			return
		}

		// Long-poll: wait for messages or timeout
		deadline := time.Now().Add(time.Duration(timeout) * time.Second)
		for time.Now().Before(deadline) {
			alloc.Mu.Lock()

			// Read up to maxMessages from queue and dequeue (read-and-delete)
			var messages []*storage.Message
			if alloc.MessageQueues != nil {
				q, ok := alloc.MessageQueues[alloc.ClientID]
				if ok && q != nil {
					// 循环读取最多 maxMessages 条（非阻塞）
					for i := 0; i < maxMessages; i++ {
						if msg, err := q.Get(); err == nil {
							messages = append(messages, msg)
						} else {
							break // 队列空
						}
					}
				}
			}

		if len(messages) > 0 {
			var respMessages []Message
			for _, msg := range messages {
				respMessages = append(respMessages, Message{
					From:      msg.From,
					Data:      base64.StdEncoding.EncodeToString(msg.Data),
					Timestamp: msg.Timestamp.Unix(),
				})
			}
			alloc.Mu.Unlock()

			resp := ReceiveResponse{Messages: respMessages}
			w.Header().Set("Content-Type", "application/json")
			json.NewEncoder(w).Encode(resp)

			// Flush the response to ensure it's sent immediately
			if f, ok := w.(http.Flusher); ok {
				f.Flush()
			}

			return
		}
		alloc.Mu.Unlock()

		time.Sleep(500 * time.Millisecond) // Short poll interval
	}

	// Timeout, return empty
	resp := ReceiveResponse{Messages: []Message{}}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(resp)

	// Flush the response
	if f, ok := w.(http.Flusher); ok {
		f.Flush()
	}
	}
}

// NewRefreshHandler returns handler for refreshing allocation
func NewRefreshHandler(store storage.Storage) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != "POST" {
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
			return
		}

		var req RefreshRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, "Invalid JSON", http.StatusBadRequest)
			return
		}

		alloc, err := store.GetAllocation(req.RelayID)
		if err != nil || alloc == nil {
			http.Error(w, "Relay not found", http.StatusNotFound)
			return
		}

		lifetime := time.Duration(req.Lifetime) * time.Second
		if lifetime == 0 {
			lifetime = 10 * time.Minute
		}

		alloc.Lifetime = lifetime
		alloc.ExpiresAt = time.Now().Add(lifetime)
		store.SaveAllocation(req.RelayID, alloc)

		resp := RefreshResponse{
			Status:   "refreshed",
			Lifetime: int(lifetime.Seconds()),
		}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(resp)
	}
}

// NewDeallocateHandler returns handler for deallocating
func NewDeallocateHandler(store storage.Storage) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != "POST" {
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
			return
		}

		var req DeallocateRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, "Invalid JSON", http.StatusBadRequest)
			return
		}

		if err := store.DeleteAllocation(req.RelayID); err != nil {
			http.Error(w, "Failed to deallocate", http.StatusInternalServerError)
			return
		}

		resp := DeallocateResponse{Status: "deallocated"}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(resp)
	}
}

// generateID generates a simple unique relay ID (replace with UUID in production)
func generateID() string {
	return fmt.Sprintf("relay_%d", time.Now().UnixNano())
}
