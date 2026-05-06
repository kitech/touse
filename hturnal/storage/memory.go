//go:build !redis && !sqlite

package storage

import (
	"log"
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

	// Clean timed out TCP connections (but don't release allocation, wait for Refresh to expire)
	for relayID, alloc := range s.turnAllocations {
		if alloc.Connections != nil {
			alloc.Mu.Lock()
			for connID, tcpConn := range alloc.Connections {
				shouldCleanup := false

				// Condition 1: Connection timed out (no activity for 5 minutes)
				if time.Since(tcpConn.LastActivity) > 5*time.Minute {
					shouldCleanup = true
					log.Printf("[Cleanup] TCP connection %s timed out (last activity: %v)",
						connID, tcpConn.LastActivity)
				}

				// Condition 2: Connection was explicitly closed
				if tcpConn.Closed {
					shouldCleanup = true
					log.Printf("[Cleanup] TCP connection %s was closed", connID)
				}

				if shouldCleanup && !tcpConn.Closed {
					tcpConn.Closed = true

					// Safely close channels (use recover to avoid panic from double close)
					func() {
						defer func() {
							if r := recover(); r != nil {
								log.Printf("[Cleanup] Recovered from panic when closing channels for %s: %v", connID, r)
							}
						}()

						// Close channels to signal connection is dead
						close(tcpConn.Incoming)
						close(tcpConn.Outgoing)
					}()

					// Remove from map and cleanup backoff/metrics
					delete(alloc.Connections, connID)
					delete(alloc.BackoffMap, connID)
					delete(alloc.MetricsMap, connID)
					log.Printf("[Cleanup] Removed TCP connection %s from allocation %s", connID, relayID)
				}
			}
			alloc.Mu.Unlock()
		}
	}
}
