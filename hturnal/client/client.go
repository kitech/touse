package client

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net"
	"net/http"
	"time"
)

// Client is compatible with pion/turn's Client
type Client struct {
	config     *ClientConfig
	httpClient *http.Client
	clientID   string    // Server-allocated "ip:port"
	relayID    string    // Server-allocated relay ID
	relayPort  int       // Pseudo-port for data plane
	conn       net.PacketConn // httpPacketConn
}

// NewClient creates a new client compatible with pion/turn
func NewClient(config *ClientConfig) (*Client, error) {
	if config.TURNServerAddr == "" {
		return nil, fmt.Errorf("TURNServerAddr is required")
	}
	return &Client{
		config:    config,
		httpClient: &http.Client{Timeout: 30 * time.Second},
	}, nil
}

// ---------- STUN Methods ----------

// GetPublicAddress gets the client's public address via STUN binding
func (c *Client) GetPublicAddress(clientID string) (*STUNBindingResponse, error) {
	reqBody := STUNBindingRequest{ClientID: clientID}
	resp := &STUNBindingResponse{}
	err := c.post("/stun/binding", reqBody, resp)
	return resp, err
}

// CheckNATType performs NAT type detection
func (c *Client) CheckNATType(clientID string) (*STUNNATCheckResponse, error) {
	reqBody := STUNNATCheckRequest{
		ClientID:     clientID,
		TestSequence: "full",
	}
	resp := &STUNNATCheckResponse{}
	err := c.post("/stun/nat-check", reqBody, resp)
	return resp, err
}

// SendBindingRequest sends a STUN binding request to the STUN server
// Compatible with pion/turn's SendBindingRequest() method
func (c *Client) SendBindingRequest() (net.Addr, error) {
	// Use the internally allocated clientID
	resp, err := c.GetPublicAddress(c.clientID)
	if err != nil {
		return nil, err
	}
	// Parse mapped address as net.Addr
	addr, err := net.ResolveUDPAddr("udp", resp.MappedAddress)
	if err != nil {
		return nil, err
	}
	return addr, nil
}

// SendBindingRequestTo sends a STUN binding request to a specific address
// Compatible with pion/turn's SendBindingRequestTo(to net.Addr) method
func (c *Client) SendBindingRequestTo(to net.Addr) (net.Addr, error) {
	reqBody := STUNBindingRequestToRequest{
		ClientID:  c.clientID,
		TargetAddr: to.String(),
	}
	resp := &STUNBindingRequestToResponse{}
	err := c.post("/stun/binding-to", reqBody, resp)
	if err != nil {
		return nil, err
	}
	// Parse mapped address as net.Addr
	addr, err := net.ResolveUDPAddr("udp", resp.MappedAddress)
	if err != nil {
		return nil, err
	}
	return addr, nil
}

// ---------- TURN Methods (pion/turn compatible) ----------

// Allocate allocates a TURN relay resource, returns net.PacketConn
// Compatible with pion/turn's Allocate() method
func (c *Client) Allocate() (net.PacketConn, error) {
	// POST /turn/allocate (server will allocate automatically based on client IP)
	reqBody := map[string]interface{}{} // empty JSON object
	data, _ := json.Marshal(reqBody)
	resp, err := c.httpClient.Post(
		c.config.TURNServerAddr+"/turn/allocate",
		"application/json",
		bytes.NewBuffer(data),
	)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("Allocate failed: HTTP %d", resp.StatusCode)
	}

	// Parse response
	var result AllocateResponse
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, err
	}

	// Save server-allocated values
	c.clientID = result.ClientID
	c.relayID = result.RelayID
	c.relayPort = result.RelayPort

	// Create httpPacketConn
	c.conn = &httpPacketConn{
		serverURL:  c.config.TURNServerAddr,
		relayPort:  c.relayPort,
		clientID:   c.clientID,
		httpClient: c.httpClient,
		localAddr:  &net.UDPAddr{IP: net.ParseIP("127.0.0.1"), Port: c.relayPort},
	}

	return c.conn, nil
}

// Listen starts listening for incoming messages (no-op for HTTP, compatibility with pion/turn)
func (c *Client) Listen() error {
	return nil
}

// Close releases the TURN relay
func (c *Client) Close() error {
	if c.clientID != "" {
		reqBody := map[string]interface{}{"client_id": c.clientID}
		data, _ := json.Marshal(reqBody)
		resp, err := c.httpClient.Post(
			c.config.TURNServerAddr+"/turn/deallocate",
			"application/json",
			bytes.NewBuffer(data),
		)
		if err == nil && resp != nil {
			resp.Body.Close()
		}
	}
	return nil
}

// ---------- Helper Methods ----------

// GetClientID returns the server-allocated client ID
func (c *Client) GetClientID() string {
	return c.clientID
}

// GetRelayPort returns the relay port for data plane
func (c *Client) GetRelayPort() int {
	return c.relayPort
}

// GetRelayID returns the server-allocated relay ID
func (c *Client) GetRelayID() string {
	return c.relayID
}

// SetPeerID sets the peer client ID for WriteTo
func (c *Client) SetPeerID(peerID string) {
	if c.conn != nil {
		if pc, ok := c.conn.(*httpPacketConn); ok {
			pc.SetPeerID(peerID)
		}
	}
}

// post is a helper for POST requests
func (c *Client) post(path string, reqBody, respBody interface{}) error {
	u := c.config.TURNServerAddr + path
	var body *bytes.Buffer
	if reqBody != nil {
		data, err := json.Marshal(reqBody)
		if err != nil {
			return err
		}
		body = bytes.NewBuffer(data)
	}

	resp, err := c.httpClient.Post(u, "application/json", body)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("HTTP %d", resp.StatusCode)
	}

	if respBody != nil {
		return json.NewDecoder(resp.Body).Decode(respBody)
	}
	return nil
}
