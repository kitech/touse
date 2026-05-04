package turn

import (
	"encoding/base64"
	"encoding/json"
	"fmt"
	"log"
	//	"github.com/adrianbrad/queue"
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

		// 获取客户端IP（按优先级：X-Forwarded-For → X-Real-IP → RemoteAddr.IP）
		clientIP := getClientIP(r)
		
		// 从按IP端口池分配端口（用于client_id）
		log.Printf("[Allocate] Attempting to allocate client port for IP: %s", clientIP)
		clientPort, clientID, err := globalIPPortPool.AllocateClientPort(clientIP)
		if err != nil {
			log.Printf("[Allocate] Failed to allocate client port: %v", err)
			http.Error(w, err.Error(), http.StatusServiceUnavailable)
			return
		}
		log.Printf("[Allocate] Allocated clientPort=%d, clientID=%s", clientPort, clientID)
		
		// 从全局端口池分配relay_port（用于数据平面）
		relayPort, err := globalRelayPortPool.Allocate()
		if err != nil {
			log.Printf("[Allocate] Failed to allocate relay port: %v", err)
			globalIPPortPool.ReleaseClientPort(clientIP, clientPort)
			http.Error(w, err.Error(), http.StatusServiceUnavailable)
			return
		}
		log.Printf("[Allocate] Allocated relayPort=%d", relayPort)
		
		// 清理该clientID的旧allocation
		if err := store.DeleteAllocationsByClientID(clientID); err != nil {
			globalIPPortPool.ReleaseClientPort(clientIP, clientPort)
			globalRelayPortPool.Release(relayPort)
			http.Error(w, "Failed to cleanup old allocations", http.StatusInternalServerError)
			return
		}
		
		// 生成内部relayID
		relayID := generateID()
		alloc := &storage.TURNAllocation{
			RelayID:       relayID,
			ClientID:      clientID,       // 服务端分配的 "ip:port"
			RelayPort:     relayPort,       // 伪端口号
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
			ClientID:   clientID,                     // 返回 "ip:port"
			RelayID:   relayID,
			RelayPort:  relayPort,
			RelayPath:  fmt.Sprintf("/relay/%d", relayPort),
			Lifetime:  int(alloc.Lifetime.Seconds()),
		}
		
		log.Printf("Allocate response: clientID=%s, relayPort=%d, relayID=%s", clientID, relayPort, relayID)
		
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
	if peerAlloc.MessageQueues == nil {
		peerAlloc.MessageQueues = make(map[string][]*storage.Message)
	}
	peerAlloc.MessageQueues[peerAlloc.ClientID] = append(peerAlloc.MessageQueues[peerAlloc.ClientID], msg)
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

			// Read up to maxMessages from slice and dequeue (read-and-delete)
			var messages []*storage.Message
			if alloc.MessageQueues != nil {
				if msgs, ok := alloc.MessageQueues[alloc.ClientID]; ok && len(msgs) > 0 {
					// 读取最多 maxMessages 条
					count := maxMessages
					if count > len(msgs) {
						count = len(msgs)
					}
					messages = msgs[:count]
					// 从slice中删除已读取的消息
					alloc.MessageQueues[alloc.ClientID] = msgs[count:]
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
