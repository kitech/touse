package storage

import (
	"sync"
	"time"
)

// STUNSession stores STUN session data
type STUNSession struct {
	ClientID   string
	PublicIP   string
	PublicPort int
	TestResults map[string]interface{}
	ExpiresAt  time.Time
}

// TURNAllocation stores TURN relay allocation
type TURNAllocation struct {
	RelayID       string
	ClientID      string                              // 服务端分配的 "ip:port"
	RelayPort     int                                 // 伪端口号（用于数据平面）
	Permissions   map[string]bool
	MessageQueues map[string][]*Message
	IncomingQueue chan *PortData                      // Peer→Owner 数据队列
	OutgoingQueue chan *PortData                      // Owner→Peer 数据队列
	Lifetime      time.Duration
	ExpiresAt     time.Time
	Mu            sync.RWMutex
}

// PortData represents data in relay port queues (原始二进制+元信息)
type PortData struct {
	From      string
	Data      []byte
	Timestamp time.Time
}

// StreamState stores stream relay state
type StreamState struct {
	StreamID  string
	RelayID   string
	PeerID    string
	Chunks    map[int][]byte // seq -> data
	MaxSeq    int
	ExpiresAt time.Time
	Mu         sync.RWMutex
}

// Message represents a pending message
type Message struct {
	From      string
	Data      []byte
	Timestamp time.Time
}

// Storage defines the interface for all storage backends
type Storage interface {
	// STUN
	SaveSTUNSession(id string, session *STUNSession) error
	GetSTUNSession(id string) (*STUNSession, error)

	// TURN
	SaveAllocation(relayID string, alloc *TURNAllocation) error
	GetAllocation(relayID string) (*TURNAllocation, error)
	GetAllocationByClientID(clientID string) (*TURNAllocation, error)
	GetAllocationByPort(port int) (*TURNAllocation, error)
	DeleteAllocation(relayID string) error
	DeleteAllocationsByClientID(clientID string) error

	// Stream
	SaveStream(streamID string, stream *StreamState) error
	GetStream(streamID string) (*StreamState, error)

	// Cleanup
	StartCleanup(interval time.Duration)
}
