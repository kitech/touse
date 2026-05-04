// Package client provides a TURN client compatible with pion/turn API
package client

// ========== pion/turn compatible types ==========

// ClientConfig is compatible with pion/turn's ClientConfig
type ClientConfig struct {
	// Standard fields (consistent with pion/turn)
	STUNServerAddr string // STUN server address (kept for compatibility)
	TURNServerAddr string // hturnal server URL (e.g. "http://localhost:8080")
	Username       string // Reserved for future authentication
	Password       string // Reserved for future authentication
	Realm          string // Reserved for future authentication
	Software       string // Reserved for client identification
	RTO            int    // Reserved for retransmission timeout
	Conn           interface{} // Reserved for pion/turn compatibility
	Net            interface{} // Reserved for pion/turn compatibility
	LoggerFactory  interface{} // Reserved for pion/turn compatibility

	// hturnal extension: no ClientID field needed
	// Server will allocate client_id automatically
}

// NewClientConfig creates a new client config
func NewClientConfig(serverURL string) *ClientConfig {
	return &ClientConfig{
		TURNServerAddr: serverURL,
	}
}

// ========== STUN types (local definitions for client) ==========

// STUNBindingRequest is the request for STUN binding
type STUNBindingRequest struct {
	ClientID string `json:"client_id"`
}

// STUNBindingResponse is the response for STUN binding
type STUNBindingResponse struct {
	MappedAddress string `json:"mapped_address"`
	Xored         bool   `json:"xored"`
	Source        string `json:"source"`
}

// STUNNATCheckRequest is the request for NAT type detection
type STUNNATCheckRequest struct {
	ClientID     string `json:"client_id"`
	TestSequence string `json:"test_sequence"`
}

// STUNNATCheckResponse is the response for NAT type detection
type STUNNATCheckResponse struct {
	NATType   string                 `json:"nat_type"`
	PublicIP  string                 `json:"public_ip"`
	Details   map[string]interface{} `json:"details"`
}

// STUNBindingRequestToRequest is the request for SendBindingRequestTo
type STUNBindingRequestToRequest struct {
	ClientID   string `json:"client_id"`
	TargetAddr string `json:"target_addr"`
}

// STUNBindingRequestToResponse is the response for SendBindingRequestTo
type STUNBindingRequestToResponse struct {
	MappedAddress string `json:"mapped_address"`
	Source        string `json:"source"`
}

// ========== TURN types (local definitions for client) ==========

// AllocateResponse is the response for TURN allocate
type AllocateResponse struct {
	ClientID   string `json:"client_id"`
	RelayID    string `json:"relay_id"`
	RelayPort  int    `json:"relay_port"`
	RelayPath  string `json:"relay_path"`
	Lifetime   int    `json:"lifetime"`
}

// StreamStartResponse is the response for stream start
type StreamStartResponse struct {
	StreamID  string `json:"stream_id"`
	ChunkSize int    `json:"chunk_size"`
	TTL       int    `json:"ttl"`
}

// StreamReceiveResponse is the response for receiving stream chunks
type StreamReceiveResponse struct {
	Chunks         []StreamChunk `json:"chunks"`
	StreamComplete bool          `json:"stream_complete"`
}

// StreamChunk represents a chunk in stream
type StreamChunk struct {
	Seq  int    `json:"seq"`
	Data string `json:"data"`
}

// ========== TCP Allocation types (Phase 6) ==========

// TCPAllocateResponse is the response for TCP allocation
type TCPAllocateResponse struct {
	ClientID  string `json:"client_id"`
	RelayID   string `json:"relay_id"`
	RelayPort int    `json:"relay_port"`
	RelayPath string `json:"relay_path"`
	Lifetime  int    `json:"lifetime"`
}

// TCPDialRequest is the request for dialing via TCP
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

// TCPDeallocateRequest is the request for TCP deallocation
type TCPDeallocateRequest struct {
	RelayID string `json:"relay_id"`
}

// TCPDeallocateResponse is the response for TCP deallocation
type TCPDeallocateResponse struct {
	Status string `json:"status"`
}
