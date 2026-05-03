//go:build !redis && !sqlite

package storage

import (
	"sync"
	"time"
)

type memoryStorage struct {
	mu              sync.RWMutex
	stunSessions    map[string]*STUNSession
	turnAllocations map[string]*TURNAllocation
	streams         map[string]*StreamState
}

func NewStorage() Storage {
	return &memoryStorage{
		stunSessions:    make(map[string]*STUNSession),
		turnAllocations: make(map[string]*TURNAllocation),
		streams:         make(map[string]*StreamState),
	}
}

// STUN methods
func (s *memoryStorage) SaveSTUNSession(id string, session *STUNSession) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.stunSessions[id] = session
	return nil
}

func (s *memoryStorage) GetSTUNSession(id string) (*STUNSession, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	session, ok := s.stunSessions[id]
	if !ok {
		return nil, nil
	}
	return session, nil
}

// TURN methods
func (s *memoryStorage) SaveAllocation(relayID string, alloc *TURNAllocation) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.turnAllocations[relayID] = alloc
	return nil
}

func (s *memoryStorage) GetAllocation(relayID string) (*TURNAllocation, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	alloc, ok := s.turnAllocations[relayID]
	if !ok {
		return nil, nil
	}
	return alloc, nil
}

func (s *memoryStorage) GetAllocationByClientID(clientID string) (*TURNAllocation, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	for _, alloc := range s.turnAllocations {
		if alloc.ClientID == clientID {
			return alloc, nil
		}
	}
	return nil, nil
}

func (s *memoryStorage) GetAllocationByPort(port int) (*TURNAllocation, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	for _, alloc := range s.turnAllocations {
		if alloc.RelayPort == port {
			return alloc, nil
		}
	}
	return nil, nil
}

func (s *memoryStorage) DeleteAllocation(relayID string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	delete(s.turnAllocations, relayID)
	return nil
}

func (s *memoryStorage) DeleteAllocationsByClientID(clientID string) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	var toDelete []string
	for relayID, alloc := range s.turnAllocations {
		if alloc.ClientID == clientID {
			toDelete = append(toDelete, relayID)
		}
	}

	for _, relayID := range toDelete {
		delete(s.turnAllocations, relayID)
	}
	return nil
}

// Stream methods
func (s *memoryStorage) SaveStream(streamID string, stream *StreamState) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.streams[streamID] = stream
	return nil
}

func (s *memoryStorage) GetStream(streamID string) (*StreamState, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	stream, ok := s.streams[streamID]
	if !ok {
		return nil, nil
	}
	return stream, nil
}

// StartCleanup starts the cleanup goroutine
func (s *memoryStorage) StartCleanup(interval time.Duration) {
	go func() {
		ticker := time.NewTicker(interval)
		defer ticker.Stop()
		for range ticker.C {
			s.cleanupExpired()
		}
	}()
}

// Cleanup expired data
func (s *memoryStorage) cleanupExpired() {
	s.mu.Lock()
	defer s.mu.Unlock()

	now := time.Now()

	// Clean STUN sessions
	for id, session := range s.stunSessions {
		if now.After(session.ExpiresAt) {
			delete(s.stunSessions, id)
		}
	}

	// Clean TURN allocations (port release logic should be in turn layer)
	for id, alloc := range s.turnAllocations {
		if now.After(alloc.ExpiresAt) {
			// TODO: Port release should be handled in turn layer to avoid circular dependency
			// For now, just delete the allocation
			delete(s.turnAllocations, id)
		}
	}

	// Clean streams
	for id, stream := range s.streams {
		if now.After(stream.ExpiresAt) {
			delete(s.streams, id)
		}
	}
}
