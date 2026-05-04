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

// TCPConnection represents a TCP-like connection between two clients
type TCPConnection struct {
	ConnID      string
	OwnerID     string          // The client who initiated the connection (caller of DialTCP)
	PeerID      string          // The peer who accepted the connection
	OwnerPort   int             // Owner's relay port (for URL routing)
	Incoming    chan *PortData  // Data from peer to owner
	Outgoing    chan *PortData  // Data from owner to peer
	CreatedAt   time.Time
}

// TURNAllocation stores TURN relay allocation
type TURNAllocation struct {
	RelayID       string
	ClientID      string                              // 服务端分配的 "ip:port"
	RelayPort     int                                 // 伪端口号（用于数据平面）
	Permissions   map[string]bool
	MessageQueues map[string][]*Message
	IncomingQueue chan *PortData                      // Peer→Owner 数据队列 (UDP-like)
	OutgoingQueue chan *PortData                      // Owner→Peer 数据队列 (UDP-like)
	Lifetime      time.Duration
	ExpiresAt     time.Time
	Mu            sync.RWMutex

	// TCP connection management
	PendingConnections chan *TCPConnection           // 待接受的 TCP 连接
	Connections        map[string]*TCPConnection     // connID -> connection
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
