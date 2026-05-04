package client

import (
	"encoding/json"
	"fmt"
	"log"
	"net"
)

// TCPAllocation corresponds to pion/turn's TCPAllocation
type TCPAllocation struct {
	client    *Client
	relayID   string
	relayPort int
	localAddr net.Addr
}

// RelayID returns the relay ID
func (a *TCPAllocation) RelayID() string {
	return a.relayID
}

// RelayPort returns the relay port
func (a *TCPAllocation) RelayPort() int {
	return a.relayPort
}

// AllocateTCP creates a new TCP allocation
// Corresponds to pion/turn's AllocateTCP() method
func (c *Client) AllocateTCP() (*TCPAllocation, error) {
	resp := &TCPAllocateResponse{}
	err := c.post("/turn/tcp/allocate", nil, resp)
	if err != nil {
		return nil, err
	}

	// Save server-allocated values
	c.clientID = resp.ClientID
	c.relayID = resp.RelayID
	c.relayPort = resp.RelayPort

	// Debug log
	log.Printf("[AllocateTCP] clientID=%s, relayID=%s, relayPort=%d", c.clientID, c.relayID, c.relayPort)

	// Fallback: if server didn't return clientID, generate one
	if c.clientID == "" {
		c.clientID = fmt.Sprintf("client_%s", c.relayID)
		log.Printf("[AllocateTCP] Warning: server returned empty client_id, using %s", c.clientID)
	}

	return &TCPAllocation{
		client:    c,
		relayID:   resp.RelayID,
		relayPort: resp.RelayPort,
		localAddr: &net.TCPAddr{IP: net.ParseIP("127.0.0.1"), Port: resp.RelayPort},
	}, nil
}

// DialTCP dials to a peer via TCP relay
// Corresponds to pion/turn's TCPAllocation.DialTCP() method
func (a *TCPAllocation) DialTCP(peerID string) (net.Conn, error) {
	reqBody := TCPDialRequest{
		RelayID: a.relayID,
		PeerID:  peerID,
	}

	resp := &TCPDialResponse{}
	err := a.client.post("/turn/tcp/dial", reqBody, resp)
	if err != nil {
		return nil, err
	}

	// Return httpTCPConn
	return &httpTCPConn{
		serverURL:  a.client.config.TURNServerAddr,
		connID:    resp.ConnectionID,
		relayPort:  a.relayPort,
		clientID:   a.client.clientID,
		httpClient: a.client.httpClient,
	}, nil
}

// Accept accepts an incoming TCP connection (long-poll)
// Corresponds to pion/turn's TCPAllocation.Accept() method
func (a *TCPAllocation) Accept() (net.Conn, error) {
	// GET /turn/tcp/accept?relay_id=xxx (long-poll)
	url := fmt.Sprintf("%s/turn/tcp/accept?relay_id=%s", a.client.config.TURNServerAddr, a.relayID)

	resp, err := a.client.httpClient.Get(url)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		return nil, fmt.Errorf("HTTP %d", resp.StatusCode)
	}

	var acceptResp TCPAcceptResponse
	if err := json.NewDecoder(resp.Body).Decode(&acceptResp); err != nil {
		return nil, err
	}

	// Return httpTCPConn for the accepted connection
	return &httpTCPConn{
		serverURL:  a.client.config.TURNServerAddr,
		connID:    acceptResp.ConnectionID,
		relayPort:  a.relayPort,
		clientID:   a.client.clientID,
		httpClient: a.client.httpClient,
	}, nil
}

// Addr returns the relay address
// Corresponds to pion/turn's TCPAllocation.Addr() method
func (a *TCPAllocation) Addr() net.Addr {
	return a.localAddr
}

// Close releases the TCP allocation
// Corresponds to pion/turn's TCPAllocation.Close() method
func (a *TCPAllocation) Close() error {
	reqBody := TCPDeallocateRequest{RelayID: a.relayID}
	resp := &TCPDeallocateResponse{}
	return a.client.post("/turn/tcp/deallocate", reqBody, resp)
}
