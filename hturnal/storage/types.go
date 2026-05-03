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
	RelayID     string
	ClientID    string
	Permissions map[string]bool // peer IDs
	PendingData  map[string][]*Message // peer_id -> messages
	Lifetime    time.Duration
	ExpiresAt   time.Time
	Mu           sync.RWMutex
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
	DeleteAllocation(relayID string) error

	// Stream
	SaveStream(streamID string, stream *StreamState) error
	GetStream(streamID string) (*StreamState, error)

	// Cleanup
	StartCleanup(interval time.Duration)
}
