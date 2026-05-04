package client

import (
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

	resp, err := c.httpClient.Get(url)
	if err != nil {
		return 0, err
	}
	defer resp.Body.Close()

	if resp.StatusCode == 204 {
		// No content, retry or timeout
		return 0, fmt.Errorf("no data available")
	}

	if resp.StatusCode != 200 {
		return 0, fmt.Errorf("HTTP %d", resp.StatusCode)
	}

	n, err := io.ReadFull(resp.Body, b)
	return n, err
}

// Write implements net.Conn
func (c *httpTCPConn) Write(b []byte) (int, error) {
	// POST /relay/tcp/{port}/{conn_id}
	url := fmt.Sprintf("%s/relay/tcp/%d/%s",
		c.serverURL, c.relayPort, c.connID)

	resp, err := c.httpClient.Post(url, "application/octet-stream", nil)
	if err != nil {
		return 0, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		return 0, fmt.Errorf("HTTP %d", resp.StatusCode)
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
