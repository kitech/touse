// Package client provides httpPacketConn implementing net.PacketConn
package client;

import (
	"bytes"
	"fmt"
	"io"
	"net"
	"net/http"
	"time"
)

// httpPacketConn implements net.PacketConn using HTTP long-polling
type httpPacketConn struct {
	serverURL  string
	relayPort  int
	clientID   string
	httpClient *http.Client
	localAddr  net.Addr
}

// ReadFrom implements net.PacketConn
func (c *httpPacketConn) ReadFrom(b []byte) (int, net.Addr, error) {
	url := fmt.Sprintf("%s/relay/%d?timeout=30", c.serverURL, c.relayPort)
	for {
		resp, err := c.httpClient.Get(url)
		if err != nil {
			return 0, nil, err
		}

		if resp.StatusCode == http.StatusNoContent {
			resp.Body.Close()
			time.Sleep(100 * time.Millisecond)
			continue
		}

		if resp.StatusCode != http.StatusOK {
			resp.Body.Close()
			return 0, nil, fmt.Errorf("HTTP %d", resp.StatusCode)
		}

		n, err := io.ReadFull(resp.Body, b)
		resp.Body.Close()

		// Get sender info from headers
		from := resp.Header.Get("X-Hturnal-From")
		var addr net.Addr
		if from != "" {
			addr, _ = net.ResolveUDPAddr("udp", from+":0")
		} else {
			addr = &net.UDPAddr{IP: net.ParseIP("127.0.0.1"), Port: 0}
		}

		return n, addr, err
	}
}

// WriteTo implements net.PacketConn
func (c *httpPacketConn) WriteTo(b []byte, addr net.Addr) (int, error) {
	url := fmt.Sprintf("%s/relay/%d", c.serverURL, c.relayPort)
	req, _ := http.NewRequest("POST", url, bytes.NewReader(b))
	req.Header.Set("X-Hturnal-Client-ID", c.clientID)
	req.Header.Set("Content-Type", "application/octet-stream")

	// Set X-Hturnal-Xor-Peer-Address from addr
	if addr != nil {
		req.Header.Set("X-Hturnal-Xor-Peer-Address", addr.String())
	}

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return 0, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return 0, fmt.Errorf("HTTP %d", resp.StatusCode)
	}

	return len(b), nil
}

// Close implements net.PacketConn
func (c *httpPacketConn) Close() error {
	return nil
}

// LocalAddr implements net.PacketConn
func (c *httpPacketConn) LocalAddr() net.Addr {
	return c.localAddr
}

// SetDeadline implements net.PacketConn
func (c *httpPacketConn) SetDeadline(t time.Time) error {
	return nil
}

// SetReadDeadline implements net.PacketConn
func (c *httpPacketConn) SetReadDeadline(t time.Time) error {
	return nil
}

// SetWriteDeadline implements net.PacketConn
func (c *httpPacketConn) SetWriteDeadline(t time.Time) error {
	return nil
}
