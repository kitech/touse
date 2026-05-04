package turn

// AllocateRequest is the request for TURN allocate
type AllocateRequest struct {
	ClientID  string `json:"client_id"`
	Username  string `json:"username,omitempty"`
	Password  string `json:"password,omitempty"`
}

// AllocateResponse is the response for TURN allocate
type AllocateResponse struct {
	ClientID   string `json:"client_id"`     // 服务端分配的客户端标识 "ip:port"
	RelayID   string `json:"relay_id"`
	RelayPort int    `json:"relay_port"`     // 伪端口（用于数据平面）
	RelayPath string `json:"relay_path"`     // /relay/{port}
	Lifetime  int    `json:"lifetime"`
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

// ========= TCP Allocation Types (Phase 6) =========

// TCPAllocateRequest is the request for TCP allocation
type TCPAllocateRequest struct {
	ClientID string `json:"client_id"`
}

// TCPAllocateResponse is the response for TCP allocation
type TCPAllocateResponse struct {
	ClientID   string `json:"client_id"`
	RelayID    string `json:"relay_id"`
	RelayPort  int    `json:"relay_port"`
	RelayPath  string `json:"relay_path"`
	Lifetime   int    `json:"lifetime"`
}

// TCPDialRequest is the request for dialing to a peer via TCP
type TCPDialRequest struct {
	RelayID string `json:"relay_id"`
	PeerID  string `json:"peer_id"`
}

// TCPDialResponse is the response for TCP dial
type TCPDialResponse struct {
	ConnectionID string `json:"connection_id"`
}

// TCPAcceptResponse is the response for accepting TCP connections
type TCPAcceptResponse struct {
	ConnectionID string `json:"connection_id"`
	PeerID      string `json:"peer_id"`
}

// TCPDeallocateRequest is the request for deallocating TCP
type TCPDeallocateRequest struct {
	RelayID string `json:"relay_id"`
}

// TCPDeallocateResponse is the response for TCP deallocate
type TCPDeallocateResponse struct {
	Status string `json:"status"`
}
