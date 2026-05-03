package client;

// STUN types;
type STUNBindingRequest struct {
	ClientID string `json:"client_id"`;
};

type STUNBindingResponse struct {
	MappedAddress string `json:"mapped_address"`;
	Xored         bool   `json:"xored"`;
	Source        string `json:"source"`;
};

type STUNNATCheckRequest struct {
	ClientID     string `json:"client_id"`;
	TestSequence string `json:"test_sequence"`;
};

type STUNNATCheckResponse struct {
	NATType   string                 `json:"nat_type"`;
	PublicIP  string                 `json:"public_ip"`;
	Details   map[string]interface{} `json:"details"`;
};

// TURN types;
type TURNAllocateRequest struct {
	ClientID string `json:"client_id"`;
	Username string `json:"username,omitempty"`;
	Password string `json:"password,omitempty"`;
};

type TURNAllocateResponse struct {
	RelayID      string `json:"relay_id"`;
	RelayAddress string `json:"relay_address"`;
	Lifetime     int    `json:"lifetime"`;
};

type TURNSendRequest struct {
	RelayID string `json:"relay_id"`;
	PeerID  string `json:"peer_id"`;
	Data    string `json:"data"`; // base64;
	TTL     int    `json:"ttl,omitempty"`;
};

type TURNReceiveResponse struct {
	Messages []TURNMessage `json:"messages"`;
};

type TURNMessage struct {
	From      string `json:"from"`;
	Data      string `json:"data"`; // base64;
	Timestamp int64  `json:"timestamp"`;
};

type TURNRefreshRequest struct {
	RelayID  string `json:"relay_id"`;
	Lifetime int    `json:"lifetime"`;
};

type TURNRefreshResponse struct {
	Status   string `json:"status"`;
	Lifetime int    `json:"lifetime"`;
};

// Stream types;
type StreamStartRequest struct {
	ClientID string `json:"client_id"`;
	PeerID   string `json:"peer_id"`;
	RelayID  string `json:"relay_id,omitempty"`;
};

type StreamStartResponse struct {
	StreamID  string `json:"stream_id"`;
	ChunkSize int    `json:"chunk_size"`;
	TTL       int    `json:"ttl"`;
};

type StreamChunk struct {
	StreamID string `json:"stream_id"`;
	ChunkSeq int    `json:"chunk_seq"`;
	Data     string `json:"data"`; // base64;
	Hash     string `json:"hash,omitempty"`;
};

type StreamReceiveResponse struct {
	Chunks        []StreamChunk `json:"chunks"`;
	StreamComplete bool          `json:"stream_complete"`;
};
