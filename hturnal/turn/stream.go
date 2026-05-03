package turn

import (
	"encoding/base64"
	"encoding/json"
	"fmt"
	"github.com/kitech/touse/hturnal/storage"
	"net/http"
	"time"
)

// NewStreamStartHandler returns handler for starting a stream
func NewStreamStartHandler(store storage.Storage) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != "POST" {
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
			return
		}

		var req StreamStartRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, "Invalid JSON", http.StatusBadRequest)
			return
		}

		// Verify relay exists if provided
		if req.RelayID != "" {
			alloc, err := store.GetAllocation(req.RelayID)
			if err != nil || alloc == nil {
				http.Error(w, "Relay not found", http.StatusNotFound)
				return
			}
		}

		// Generate stream ID
		streamID := generateStreamID()
		stream := &storage.StreamState{
			StreamID:  streamID,
			RelayID:   req.RelayID,
			PeerID:    req.PeerID,
			Chunks:    make(map[int][]byte),
			MaxSeq:    -1,
			ExpiresAt: time.Now().Add(5 * time.Minute),
		}

		if err := store.SaveStream(streamID, stream); err != nil {
			http.Error(w, "Failed to save stream", http.StatusInternalServerError)
			return
		}

		resp := StreamStartResponse{
			StreamID:  streamID,
			ChunkSize: 16384, // 16KB default
			TTL:       int(time.Until(stream.ExpiresAt).Seconds()),
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(resp)
	}
}

// NewStreamSendHandler returns handler for sending stream chunk
func NewStreamSendHandler(store storage.Storage) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != "POST" {
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
			return
		}

		var req StreamSendRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, "Invalid JSON", http.StatusBadRequest)
			return
		}

		stream, err := store.GetStream(req.StreamID)
		if err != nil || stream == nil {
			http.Error(w, "Stream not found", http.StatusNotFound)
			return
		}

		// Decode base64 chunk
		data, err := base64.StdEncoding.DecodeString(req.Data)
		if err != nil {
			http.Error(w, "Invalid base64 data", http.StatusBadRequest)
			return
		}

		stream.Mu.Lock()
		stream.Chunks[req.ChunkSeq] = data
		if req.ChunkSeq > stream.MaxSeq {
			stream.MaxSeq = req.ChunkSeq
		}
		stream.Mu.Unlock()

		resp := map[string]interface{}{
			"status":    "chunk received",
			"next_seq": req.ChunkSeq + 1,
		}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(resp)
	}
}

// NewStreamReceiveHandler returns handler for receiving stream chunks (long-poll)
func NewStreamReceiveHandler(store storage.Storage) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != "GET" {
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
			return
		}

		streamID := r.URL.Query().Get("stream_id")
		timeout := 30 // seconds
		if t := r.URL.Query().Get("timeout"); t != "" {
			fmt.Sscanf(t, "%d", &timeout)
		}

		if streamID == "" {
			http.Error(w, "Missing stream_id parameter", http.StatusBadRequest)
			return
		}

		stream, err := store.GetStream(streamID)
		if err != nil || stream == nil {
			http.Error(w, "Stream not found", http.StatusNotFound)
			return
		}

		// Long-poll: wait for chunks or timeout
		deadline := time.Now().Add(time.Duration(timeout) * time.Second)
		for time.Now().Before(deadline) {
			stream.Mu.RLock()
			chunkCount := len(stream.Chunks)
			stream.Mu.RUnlock()

			if chunkCount > 0 {
				stream.Mu.RLock()
				var chunks []StreamChunk
				for seq, data := range stream.Chunks {
					chunks = append(chunks, StreamChunk{
						Seq:  seq,
						Data: base64.StdEncoding.EncodeToString(data),
					})
					if seq >= stream.MaxSeq {
						break
					}
				}
				stream.Mu.RUnlock()

				// Clear received chunks
				stream.Mu.Lock()
				stream.Chunks = make(map[int][]byte)
				stream.Mu.Unlock()

				resp := StreamReceiveResponse{
					Chunks:        chunks,
					StreamComplete: false,
				}
				w.Header().Set("Content-Type", "application/json")
				json.NewEncoder(w).Encode(resp)
				return
			}

			time.Sleep(500 * time.Millisecond)
		}

		// Timeout
		resp := StreamReceiveResponse{
			Chunks:        []StreamChunk{},
			StreamComplete: false,
		}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(resp)
	}
}

// NewStreamEndHandler returns handler for ending stream
func NewStreamEndHandler(store storage.Storage) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != "POST" {
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
			return
		}

		var req StreamEndRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, "Invalid JSON", http.StatusBadRequest)
			return
		}

		stream, err := store.GetStream(req.StreamID)
		if err != nil || stream == nil {
			http.Error(w, "Stream not found", http.StatusNotFound)
			return
		}

		// Mark stream as complete (could delete or mark)
		// For simplicity, we keep it until TTL expires

		resp := StreamEndResponse{Status: "stream ended"}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(resp)
	}
}

// generateStreamID generates a simple unique stream ID
func generateStreamID() string {
	return fmt.Sprintf("stream_%d", time.Now().UnixNano())
}
