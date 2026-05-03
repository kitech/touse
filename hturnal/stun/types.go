package stun

// BindingRequest is the request for STUN binding
type BindingRequest struct {
	ClientID string `json:"client_id"`
}

// BindingResponse is the response for STUN binding
type BindingResponse struct {
	MappedAddress string `json:"mapped_address"`
	Xored         bool   `json:"xored"`
	Source        string `json:"source"`
}

// NATCheckRequest is the request for NAT type detection
type NATCheckRequest struct {
	ClientID     string `json:"client_id"`
	TestSequence string `json:"test_sequence"`
}

// NATCheckResponse is the response for NAT type detection
type NATCheckResponse struct {
	NATType   string                 `json:"nat_type"`
	PublicIP  string                 `json:"public_ip"`
	Details   map[string]interface{} `json:"details"`
}
