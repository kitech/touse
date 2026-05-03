//go:build sqlite

package storage

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"os"
	"time"

	_ "github.com/mattn/go-sqlite3"
)

type sqliteStorage struct {
	db *sql.DB
}

func NewStorage() Storage {
	path := getSqlitePath()
	db, err := sql.Open("sqlite3", path)
	if err != nil {
		panic(fmt.Sprintf("Failed to open SQLite database: %v", err))
	}

	// Create tables
	if err := initSqliteTables(db); err != nil {
		panic(fmt.Sprintf("Failed to initialize tables: %v", err))
	}

	return &sqliteStorage{db: db}
}

func getSqlitePath() string {
	if path := os.Getenv("SQLITE_PATH"); path != "" {
		return path
	}
	return "hturnal.db"
}

func initSqliteTables(db *sql.DB) error {
	// STUN sessions table
	_, err := db.Exec(`
		CREATE TABLE IF NOT EXISTS stun_sessions (
			id TEXT PRIMARY KEY,
			data TEXT NOT NULL,
			expires_at TIMESTAMP NOT NULL
		)
	`)
	if err != nil {
		return err
	}

	// TURN allocations table
	_, err = db.Exec(`
		CREATE TABLE IF NOT EXISTS turn_allocations (
			relay_id TEXT PRIMARY KEY,
			client_id TEXT NOT NULL,
			data TEXT NOT NULL,
			expires_at TIMESTAMP NOT NULL
		)
	`)
	if err != nil {
		return err
	}

	// Streams table
	_, err = db.Exec(`
		CREATE TABLE IF NOT EXISTS streams (
			stream_id TEXT PRIMARY KEY,
			data TEXT NOT NULL,
			expires_at TIMESTAMP NOT NULL
		)
	`)
	if err != nil {
		return err
	}

	return nil
}

// STUN methods
func (s *sqliteStorage) SaveSTUNSession(id string, session *STUNSession) error {
	data, err := json.Marshal(session)
	if err != nil {
		return err
	}

	_, err = s.db.Exec(`
		INSERT OR REPLACE INTO stun_sessions (id, data, expires_at)
		VALUES (?, ?, ?)
	`, id, string(data), session.ExpiresAt)
	return err
}

func (s *sqliteStorage) GetSTUNSession(id string) (*STUNSession, error) {
	var data string
	var expiresAt time.Time
	err := s.db.QueryRow(`
		SELECT data, expires_at FROM stun_sessions
		WHERE id = ? AND expires_at > ?
	`, id, time.Now()).Scan(&data, &expiresAt)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}

	var session STUNSession
	if err := json.Unmarshal([]byte(data), &session); err != nil {
		return nil, err
	}
	return &session, nil
}

// TURN methods
func (s *sqliteStorage) SaveAllocation(relayID string, alloc *TURNAllocation) error {
	data, err := json.Marshal(alloc)
	if err != nil {
		return err
	}

	_, err = s.db.Exec(`
		INSERT OR REPLACE INTO turn_allocations (relay_id, client_id, data, expires_at)
		VALUES (?, ?, ?, ?)
	`, relayID, alloc.ClientID, string(data), alloc.ExpiresAt)
	return err
}

func (s *sqliteStorage) GetAllocation(relayID string) (*TURNAllocation, error) {
	var data string
	var expiresAt time.Time
	err := s.db.QueryRow(`
		SELECT data, expires_at FROM turn_allocations
		WHERE relay_id = ? AND expires_at > ?
	`, relayID, time.Now()).Scan(&data, &expiresAt)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}

	var alloc TURNAllocation
	if err := json.Unmarshal([]byte(data), &alloc); err != nil {
		return nil, err
	}
	return &alloc, nil
}

func (s *sqliteStorage) GetAllocationByClientID(clientID string) (*TURNAllocation, error) {
	var data string
	var expiresAt time.Time
	err := s.db.QueryRow(`
		SELECT data, expires_at FROM turn_allocations
		WHERE client_id = ? AND expires_at > ?
	`, clientID, time.Now()).Scan(&data, &expiresAt)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}

	var alloc TURNAllocation
	if err := json.Unmarshal([]byte(data), &alloc); err != nil {
		return nil, err
	}
	return &alloc, nil
}

func (s *sqliteStorage) DeleteAllocation(relayID string) error {
	_, err := s.db.Exec(`
		DELETE FROM turn_allocations WHERE relay_id = ?
	`, relayID)
	return err
}

// Stream methods
func (s *sqliteStorage) SaveStream(streamID string, stream *StreamState) error {
	data, err := json.Marshal(stream)
	if err != nil {
		return err
	}

	_, err = s.db.Exec(`
		INSERT OR REPLACE INTO streams (stream_id, data, expires_at)
		VALUES (?, ?, ?)
	`, streamID, string(data), stream.ExpiresAt)
	return err
}

func (s *sqliteStorage) GetStream(streamID string) (*StreamState, error) {
	var data string
	var expiresAt time.Time
	err := s.db.QueryRow(`
		SELECT data, expires_at FROM streams
		WHERE stream_id = ? AND expires_at > ?
	`, streamID, time.Now()).Scan(&data, &expiresAt)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}

	var stream StreamState
	if err := json.Unmarshal([]byte(data), &stream); err != nil {
		return nil, err
	}
	return &stream, nil
}

// Cleanup expired data
func (s *sqliteStorage) StartCleanup(interval time.Duration) {
	go func() {
		ticker := time.NewTicker(interval)
		defer ticker.Stop()
		for range ticker.C {
			s.cleanupExpired()
		}
	}()
}

func (s *sqliteStorage) cleanupExpired() {
	now := time.Now()
	s.db.Exec(`DELETE FROM stun_sessions WHERE expires_at <= ?`, now)
	s.db.Exec(`DELETE FROM turn_allocations WHERE expires_at <= ?`, now)
	s.db.Exec(`DELETE FROM streams WHERE expires_at <= ?`, now)
}
