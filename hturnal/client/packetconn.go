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
	peerID    string // 对端 clientID
	httpClient *http.Client
	localAddr  net.Addr
}

// SetPeerID sets the peer client ID for WriteTo
func (c *httpPacketConn) SetPeerID(peerID string) {
	c.peerID = peerID
}

// ReadFrom implements net.PacketConn
func (c *httpPacketConn) ReadFrom(b []byte) (int, net.Addr, error) {
	url := fmt.Sprintf("%s/relay/%d?timeout=30", c.serverURL, c.relayPort)
	for {
		req, _ := http.NewRequest("GET", url, nil)
		req.Header.Set("X-Hturnal-Client-ID", c.clientID)

		resp, err := c.httpClient.Do(req)
		if err != nil {
			return 0, nil, err
		}

		if resp.StatusCode == http.StatusNoContent {
			resp.Body.Close()
			time.Sleep(100 * time.Millisecond)
			continue
		}

		if resp.StatusCode != http.StatusOK {
			body, _ := io.ReadAll(resp.Body)
			resp.Body.Close()
			return 0, nil, fmt.Errorf("HTTP %d: %s", resp.StatusCode, string(body))
		}

		// 读取所有数据（不是固定长度）
		data, err := io.ReadAll(resp.Body)
		resp.Body.Close()

		if err != nil {
			return 0, nil, err
		}

		if len(data) == 0 {
			time.Sleep(100 * time.Millisecond)
			continue
		}

		// 复制数据到缓冲区
		n := copy(b, data)

		// Get sender info from headers
		from := resp.Header.Get("X-Hturnal-From")
		var addr net.Addr
		if from != "" {
			addr, _ = net.ResolveUDPAddr("udp", from+":0")
		} else {
			addr = &net.UDPAddr{IP: net.ParseIP("127.0.0.1"), Port: 0}
		}

		return n, addr, nil
	}
}

// WriteTo implements net.PacketConn
func (c *httpPacketConn) WriteTo(b []byte, addr net.Addr) (int, error) {
	// 数据应该发送到对端的端口，但当前设计是发送到自己的端口+头部指定对端
	// 服务器会从 X-Hturnal-Xor-Peer-Address 找到对端，把数据放入对端的队列
	url := fmt.Sprintf("%s/relay/%d", c.serverURL, c.relayPort)
	req, _ := http.NewRequest("POST", url, bytes.NewReader(b))
	req.Header.Set("Content-Type", "application/octet-stream")
	req.Header.Set("X-Hturnal-Client-ID", c.clientID)

	// 优先使用 c.peerID，其次使用 addr 参数
	targetPeer := c.peerID
	if targetPeer == "" && addr != nil {
		targetPeer = addr.String()
	}
	
	if targetPeer == "" {
		return 0, fmt.Errorf("no peer specified for WriteTo")
	}
	
	req.Header.Set("X-Hturnal-Xor-Peer-Address", targetPeer)

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return 0, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return 0, fmt.Errorf("HTTP %d: %s", resp.StatusCode, string(body))
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
