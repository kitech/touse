package client;

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"time"
)

// Client is a unified client for STUN, TURN, and Stream operations
type Client struct {
	serverURL string
	httpClient *http.Client
	relayID   string // TURN relay ID (set after Allocate)
}

// NewClient creates a new hturnal client
func NewClient(serverURL string) *Client {
	return &Client{
		serverURL: serverURL,
		httpClient: &http.Client{Timeout: 30 * time.Second},
	}
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

// ---------- TURN Methods ----------

// Allocate allocates a TURN relay resource
func (c *Client) Allocate(clientID string) (*TURNAllocateResponse, error) {
	reqBody := TURNAllocateRequest{ClientID: clientID}
	resp := &TURNAllocateResponse{}
	err := c.post("/turn/allocate", reqBody, resp)
	if err == nil && resp.RelayID != "" {
		c.relayID = resp.RelayID
	}
	return resp, err
}

// SendToPeer sends data to a peer via the relay
func (c *Client) SendToPeer(peerID string, data []byte) error {
	b64 := base64.StdEncoding.EncodeToString(data)
	reqBody := TURNSendRequest{
		RelayID: c.relayID,
		PeerID:  peerID,
		Data:    b64,
	}
	return c.post("/turn/send", reqBody, &map[string]interface{}{})
}

// Receive receives messages from the relay (long-poll)
func (c *Client) Receive(timeout int) ([]TURNMessage, error) {
	if timeout <= 0 {
		timeout = 30
	}
	u := fmt.Sprintf("%s/turn/receive?relay_id=%s&timeout=%d",
		c.serverURL, url.QueryEscape(c.relayID), timeout)

	resp, err := c.httpClient.Get(u)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("HTTP %d", resp.StatusCode)
	}

	var result TURNReceiveResponse
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, err
	}
	return result.Messages, nil
}

// Refresh refreshes the TURN allocation TTL
func (c *Client) Refresh(lifetime int) error {
	reqBody := TURNRefreshRequest{
		RelayID:  c.relayID,
		Lifetime: lifetime,
	}
	return c.post("/turn/refresh", reqBody, &map[string]interface{}{})
}

// Deallocate releases the TURN relay
func (c *Client) Deallocate() error {
	reqBody := map[string]interface{}{"relay_id": c.relayID}
	return c.post("/turn/deallocate", reqBody, &map[string]interface{}{})
}

// ---------- Stream Methods ----------

// StartStream initializes a binary stream
func (c *Client) StartStream(peerID string) (*StreamStartResponse, error) {
	reqBody := StreamStartRequest{
		ClientID: c.relayID, // Use relayID as client ID
		PeerID:   peerID,
	}
	resp := &StreamStartResponse{}
	err := c.post("/turn/stream/start", reqBody, resp)
	return resp, err
}

// SendChunk sends a stream chunk
func (c *Client) SendChunk(streamID string, seq int, data []byte) error {
	b64 := base64.StdEncoding.EncodeToString(data)
	reqBody := StreamChunk{
		StreamID: streamID,
		ChunkSeq: seq,
		Data:     b64,
	}
	return c.post("/turn/stream/send", reqBody, &map[string]interface{}{})
}

// ReceiveChunks receives stream chunks (long-poll)
func (c *Client) ReceiveChunks(streamID string, timeout int) (*StreamReceiveResponse, error) {
	if timeout <= 0 {
		timeout = 30
	}
	u := fmt.Sprintf("%s/turn/stream/receive?stream_id=%s&timeout=%d",
		c.serverURL, url.QueryEscape(streamID), timeout)

	resp, err := c.httpClient.Get(u)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("HTTP %d", resp.StatusCode)
	}

	var result StreamReceiveResponse
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, err
	}
	return &result, nil
}

// EndStream signals the end of a stream
func (c *Client) EndStream(streamID string) error {
	reqBody := map[string]interface{}{"stream_id": streamID}
	return c.post("/turn/stream/end", reqBody, &map[string]interface{}{})
}

// ---------- Helper Methods ----------

// SetRelayID sets the relay ID (useful when using existing allocation)
func (c *Client) SetRelayID(relayID string) {
	c.relayID = relayID
}

// GetRelayID returns the current relay ID
func (c *Client) GetRelayID() string {
	return c.relayID
}

// post is a helper for POST requests
func (c *Client) post(path string, reqBody, respBody interface{}) error {
	u := c.serverURL + path
	data, err := json.Marshal(reqBody)
	if err != nil {
		return err
	}

	resp, err := c.httpClient.Post(u, "application/json", bytes.NewBuffer(data))
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
