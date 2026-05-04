package client

import (
	"bytes"
	"fmt"
	"io"
	"net"
	"net/http"
	"time"
)

// httpTCPConn implements net.Conn for TCP relay simulation
type httpTCPConn struct {
	serverURL  string
	connID    string
	relayPort  int
	clientID   string
	httpClient *http.Client
	readDeadline  time.Time
	writeDeadline time.Time
}

// Read implements net.Conn
func (c *httpTCPConn) Read(b []byte) (int, error) {
	// GET /relay/tcp/{port}/{conn_id}?timeout=30
	url := fmt.Sprintf("%s/relay/tcp/%d/%s?timeout=30",
		c.serverURL, c.relayPort, c.connID)

	req, _ := http.NewRequest("GET", url, nil)
	req.Header.Set("X-Hturnal-Client-ID", c.clientID)
	req.Header.Set("Content-Type", "application/json")

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return 0, err
	}
	defer resp.Body.Close()

	if resp.StatusCode == 204 {
		// No content, retry or timeout
		return 0, fmt.Errorf("no data available")
	}

	if resp.StatusCode != 200 {
		body, _ := io.ReadAll(resp.Body)
		return 0, fmt.Errorf("HTTP %d: %s", resp.StatusCode, string(body))
	}

	// Read all data
	data, err := io.ReadAll(resp.Body)
	if err != nil {
		return 0, err
	}

	if len(data) == 0 {
		return 0, fmt.Errorf("no data available")
	}

	n := copy(b, data)
	return n, nil
}

// Write implements net.Conn
func (c *httpTCPConn) Write(b []byte) (int, error) {
	// POST /relay/tcp/{port}/{conn_id}
	url := fmt.Sprintf("%s/relay/tcp/%d/%s",
		c.serverURL, c.relayPort, c.connID)

	req, _ := http.NewRequest("POST", url, bytes.NewReader(b))
	req.Header.Set("Content-Type", "application/octet-stream")
	req.Header.Set("X-Hturnal-Client-ID", c.clientID)
	// Note: X-Hturnal-Xor-Peer-Address is not needed for TCP relay
	// The server routes data based on connID

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return 0, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		body, _ := io.ReadAll(resp.Body)
		return 0, fmt.Errorf("HTTP %d: %s", resp.StatusCode, string(body))
	}

	return len(b), nil
}

// Close implements net.Conn
func (c *httpTCPConn) Close() error {
	// Notify server to close connection
	return nil
}

// LocalAddr implements net.Conn
func (c *httpTCPConn) LocalAddr() net.Addr {
	return &net.TCPAddr{IP: net.ParseIP("127.0.0.1"), Port: c.relayPort}
}

// RemoteAddr implements net.Conn
func (c *httpTCPConn) RemoteAddr() net.Addr {
	return &net.TCPAddr{IP: net.ParseIP("127.0.0.1"), Port: 0}
}

// SetDeadline implements net.Conn
func (c *httpTCPConn) SetDeadline(t time.Time) error {
	c.readDeadline = t
	c.writeDeadline = t
	return nil
}

// SetReadDeadline implements net.Conn
func (c *httpTCPConn) SetReadDeadline(t time.Time) error {
	c.readDeadline = t
	return nil
}

// SetWriteDeadline implements net.Conn
func (c *httpTCPConn) SetWriteDeadline(t time.Time) error {
	c.writeDeadline = t
	return nil
}
