package stun

import (
	"encoding/json"
	"fmt"
	"github.com/kitech/touse/hturnal/storage"
	"net/http"
	"strings"
	"time"
)

// NewBindingHandler returns a handler for STUN binding
func NewBindingHandler(store storage.Storage) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != "POST" {
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
			return
		}

		var req BindingRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, "Invalid JSON", http.StatusBadRequest)
			return
		}

		ip := getClientIP(r)
		portStr := getClientPort(r)
		addr := fmt.Sprintf("%s:%s", ip, portStr)

		portNum := 0
		fmt.Sscanf(portStr, "%d", &portNum)

		session := &storage.STUNSession{
			ClientID:   req.ClientID,
			PublicIP:   ip,
			PublicPort: portNum,
			ExpiresAt:  time.Now().Add(5 * time.Minute),
		}
		store.SaveSTUNSession(req.ClientID, session)

		resp := BindingResponse{
			MappedAddress: addr,
			Xored:         false,
			Source:        "http-stun",
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(resp)
	}
}

// NewNATCheckHandler returns a handler for NAT type detection
func NewNATCheckHandler(store storage.Storage) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != "POST" {
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
			return
		}

		var req NATCheckRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, "Invalid JSON", http.StatusBadRequest)
			return
		}

		ip := getClientIP(r)

		// Single IP mode: cannot perform full test
		resp := NATCheckResponse{
			NATType: "Unknown (single IP)",
			PublicIP:  ip,
			Details: map[string]interface{}{
				"note": "Full NAT detection requires multi-IP server",
			},
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(resp)
	}
}

func getClientIP(r *http.Request) string {
	if ip := r.Header.Get("X-Real-IP"); ip != "" {
		return ip
	}
	if ip := r.Header.Get("X-Forwarded-For"); ip != "" {
		// X-Forwarded-For may contain multiple IPs, take the first
		parts := strings.Split(ip, ",")
		return strings.TrimSpace(parts[0])
	}
	// Use RemoteAddr (format: ip:port)
	addr := r.RemoteAddr
	if colon := strings.LastIndex(addr, ":"); colon != -1 {
		return addr[:colon]
	}
	return addr
}

func getClientPort(r *http.Request) string {
	if port := r.Header.Get("X-Forwarded-Port"); port != "" {
		return port
	}
	if port := r.Header.Get("X-Real-Port"); port != "" {
		return port
	}
	// Use port from RemoteAddr
	addr := r.RemoteAddr
	if colon := strings.LastIndex(addr, ":"); colon != -1 {
		return addr[colon+1:]
	}
	return "0"
}

// NewBindingRequestToHandler handles SendBindingRequestTo
func NewBindingRequestToHandler(store storage.Storage) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != "POST" {
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
			return
		}

		var req BindingRequestToRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, "Invalid JSON", http.StatusBadRequest)
			return
		}

		if req.ClientID == "" || req.TargetAddr == "" {
			http.Error(w, "Missing client_id or target_addr", http.StatusBadRequest)
			return
		}

		// Simulate STUN Binding Request to target address
		// In a real implementation, this would send a UDP STUN request to target
		// For now, return the target address as "mapped address" (simulation)
		resp := BindingRequestToResponse{
			MappedAddress: req.TargetAddr, // Simplified: return target as mapped
			Source:        "http-stun-request-to",
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(resp)
	}
}
