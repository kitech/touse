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
