//go:build redis

package storage

import (
	"context"
	"fmt"
	"os"
	"time"

	"github.com/go-redis/redis/v8"
)

type redisStorage struct {
	client *redis.Client
	ctx    context.Context
}

func NewStorage() Storage {
	addr := getRedisAddr()
	password := os.Getenv("REDIS_PASS")

	client := redis.NewClient(&redis.Options{
		Addr:     addr,
		Password: password,
		DB:       0,
	})

	return &redisStorage{
		client: client,
		ctx:    context.Background(),
	}
}

func getRedisAddr() string {
	if addr := os.Getenv("REDIS_ADDR"); addr != "" {
		return addr
	}
	return "localhost:6379"
}

// STUN methods
func (s *redisStorage) SaveSTUNSession(id string, session *STUNSession) error {
	key := fmt.Sprintf("stun:%s", id)
	data, err := encodeSession(session)
	if err != nil {
		return err
	}
	return s.client.Set(s.ctx, key, data, session.ExpiresAt.Sub(time.Now())).Err()
}

func (s *redisStorage) GetSTUNSession(id string) (*STUNSession, error) {
	key := fmt.Sprintf("stun:%s", id)
	val, err := s.client.Get(s.ctx, key).Result()
	if err == redis.Nil {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return decodeSTUNSession([]byte(val))
}

// TURN methods
func (s *redisStorage) SaveAllocation(relayID string, alloc *TURNAllocation) error {
	key := fmt.Sprintf("turn:%s", relayID)
	data, err := encodeTURNAllocation(alloc)
	if err != nil {
		return err
	}
	// Save allocation
	if err := s.client.Set(s.ctx, key, data, alloc.ExpiresAt.Sub(time.Now())).Err(); err != nil {
		return err
	}
	// Maintain clientID -> relayID mapping
	clientKey := fmt.Sprintf("turn:client:%s", alloc.ClientID)
	return s.client.Set(s.ctx, clientKey, relayID, alloc.ExpiresAt.Sub(time.Now())).Err()
}

func (s *redisStorage) GetAllocation(relayID string) (*TURNAllocation, error) {
	key := fmt.Sprintf("turn:%s", relayID)
	val, err := s.client.Get(s.ctx, key).Result()
	if err == redis.Nil {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return decodeTURNAllocation([]byte(val))
}

func (s *redisStorage) GetAllocationByClientID(clientID string) (*TURNAllocation, error) {
	// Get relayID from client mapping
	clientKey := fmt.Sprintf("turn:client:%s", clientID)
	relayID, err := s.client.Get(s.ctx, clientKey).Result()
	if err == redis.Nil {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	// Get allocation by relayID
	return s.GetAllocation(relayID)
}

func (s *redisStorage) DeleteAllocation(relayID string) error {
	// First get the allocation to find clientID
	alloc, err := s.GetAllocation(relayID)
	if err != nil {
		return err
	}
	// Delete the allocation
	key := fmt.Sprintf("turn:%s", relayID)
	if err := s.client.Del(s.ctx, key).Err(); err != nil {
		return err
	}
	// Delete client mapping if alloc exists
	if alloc != nil {
		clientKey := fmt.Sprintf("turn:client:%s", alloc.ClientID)
		s.client.Del(s.ctx, clientKey)
	}
	return nil
}

func (s *redisStorage) DeleteAllocationsByClientID(clientID string) error {
	// Get relayID from client mapping
	clientKey := fmt.Sprintf("turn:client:%s", clientID)
	relayID, err := s.client.Get(s.ctx, clientKey).Result()
	if err == redis.Nil {
		// No allocation found for this clientID
		return nil
	}
	if err != nil {
		return err
	}

	// Delete the allocation
	allocKey := fmt.Sprintf("turn:%s", relayID)
	if err := s.client.Del(s.ctx, allocKey).Err(); err != nil {
		return err
	}

	// Delete client mapping
	s.client.Del(s.ctx, clientKey)

	return nil
}

// Stream methods
func (s *redisStorage) SaveStream(streamID string, stream *StreamState) error {
	key := fmt.Sprintf("stream:%s", streamID)
	data, err := encodeStreamState(stream)
	if err != nil {
		return err
	}
	return s.client.Set(s.ctx, key, data, stream.ExpiresAt.Sub(time.Now())).Err()
}

func (s *redisStorage) GetStream(streamID string) (*StreamState, error) {
	key := fmt.Sprintf("stream:%s", streamID)
	val, err := s.client.Get(s.ctx, key).Result()
	if err == redis.Nil {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return decodeStreamState([]byte(val))
}

// Cleanup - Redis handles TTL automatically
func (s *redisStorage) StartCleanup(interval time.Duration) {
	// Redis keys have TTL, no manual cleanup needed
}
