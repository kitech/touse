package turn

// AllocateRequest is the request for TURN allocate
type AllocateRequest struct {
	ClientID  string `json:"client_id"`
	Username  string `json:"username,omitempty"`
	Password  string `json:"password,omitempty"`
}

// AllocateResponse is the response for TURN allocate
type AllocateResponse struct {
	RelayID      string `json:"relay_id"`
	RelayAddress string `json:"relay_address"`
	Lifetime     int    `json:"lifetime"`
}

// PermissionRequest is the request for adding permissions
type PermissionRequest struct {
	RelayID string   `json:"relay_id"`
	PeerIDs  []string `json:"peer_ids"`
}

// PermissionResponse is the response for permission request
type PermissionResponse struct {
	Status string `json:"status"`
}

// SendRequest is the request for sending data via relay
type SendRequest struct {
	RelayID string `json:"relay_id"`
	PeerID  string `json:"peer_id"`
	Data    string `json:"data"` // base64 encoded
	TTL     int    `json:"ttl,omitempty"`
}

// ReceiveResponse is the response for receiving data
type ReceiveResponse struct {
	Messages []Message `json:"messages"`
}

// Message represents a message in relay
type Message struct {
	From      string `json:"from"`
	Data      string `json:"data"` // base64 encoded
	Timestamp int64  `json:"timestamp"`
}

// RefreshRequest is the request for refreshing allocation
type RefreshRequest struct {
	RelayID  string `json:"relay_id"`
	Lifetime int    `json:"lifetime"`
}

// RefreshResponse is the response for refresh
type RefreshResponse struct {
	Status   string `json:"status"`
	Lifetime int    `json:"lifetime"`
}

// DeallocateRequest is the request for deallocating
type DeallocateRequest struct {
	RelayID string `json:"relay_id"`
}

// DeallocateResponse is the response for deallocate
type DeallocateResponse struct {
	Status string `json:"status"`
}

// StreamStartRequest is the request for starting a stream
type StreamStartRequest struct {
	ClientID string `json:"client_id"`
	PeerID   string `json:"peer_id"`
	RelayID  string `json:"relay_id,omitempty"`
}

// StreamStartResponse is the response for stream start
type StreamStartResponse struct {
	StreamID  string `json:"stream_id"`
	ChunkSize int    `json:"chunk_size"`
	TTL       int    `json:"ttl"`
}

// StreamSendRequest is the request for sending stream chunk
type StreamSendRequest struct {
	StreamID string `json:"stream_id"`
	ChunkSeq int    `json:"chunk_seq"`
	Data     string `json:"data"` // base64 encoded
	Hash     string `json:"hash,omitempty"`
}

// StreamReceiveResponse is the response for receiving stream chunks
type StreamReceiveResponse struct {
	Chunks        []StreamChunk `json:"chunks"`
	StreamComplete bool          `json:"stream_complete"`
}

// StreamChunk represents a chunk in stream
type StreamChunk struct {
	Seq  int    `json:"seq"`
	Data string `json:"data"` // base64 encoded
}

// StreamEndRequest is the request for ending stream
type StreamEndRequest struct {
	StreamID string `json:"stream_id"`
}

// StreamEndResponse is the response for stream end
type StreamEndResponse struct {
	Status string `json:"status"`
}
