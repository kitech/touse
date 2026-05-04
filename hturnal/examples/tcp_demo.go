// Package main demonstrates TCP allocation using hturnal client.
// It shows how two clients can establish TCP-like communication via hturnal TURN TCP relay.
//
// # Prerequisites
//
// 1. Start hturnal server:
//
//      cd /home/gzleo/aprog/touse/hturnal
//      go build -o server ./cmd/server
//      ./server
//
// 2. Run this demo:
//
//      go build -o tcp_demo ./examples/tcp_demo.go
//      ./tcp_demo
//
// # What this demo does
//
// 1. Creates two clients (A and B)
// 2. Each allocates a TCP resource from hturnal server
// 3. B listens for incoming connections (Accept)
// 4. A dials to B (DialTCP)
// 5. A sends data, B receives and responds
// 6. Cleanup
//
// # Key APIs demonstrated
//
//   - client.NewClientConfig() - Create client config
//   - client.NewClient() - Create client instance
//   - (*Client).AllocateTCP() - Allocate TCP resource → TCPAllocation
//   - (*TCPAllocation).DialTCP(peerID) - Dial to peer → net.Conn
//   - (*TCPAllocation).Accept() - Accept incoming → net.Conn
//   - net.Conn.Write() / Read() - Send/receive data
//   - (*TCPAllocation).Close() - Release resources
//
// # Notes
//
//   - TCP relay uses HTTP long-polling under the hood
//   - The returned net.Conn is simulated via HTTP requests
//   - Write = POST /relay/tcp/{port}/{conn_id}
//   - Read = GET /relay/tcp/{port}/{conn_id} (long-poll)
//
package main

import (
	"fmt"
	"io"
	"log"
	"math/rand"
	"time"

	"github.com/kitech/touse/hturnal/client"
)

func main() {
	// Set log flags for debugging
	log.SetFlags(log.Lshortfile | log.Ldate | log.Ltime)

	// hturnal server URL
	serverURL := "http://localhost:8181"

	// ========== Step 1: Create two clients ==========

	// Client A
	configA := client.NewClientConfig(serverURL)
	cA, err := client.NewClient(configA)
	if err != nil {
		log.Fatal("Failed to create client A:", err)
	}

	// Client B
	configB := client.NewClientConfig(serverURL)
	cB, err := client.NewClient(configB)
	if err != nil {
		log.Fatal("Failed to create client B:", err)
	}

	// ========== Step 2: Allocate TCP resources ==========

	// Client A allocates TCP
	tcpA, err := cA.AllocateTCP()
	if err != nil {
		log.Fatal("AllocateTCP A failed:", err)
	}
	log.Printf("A: TCP allocated, relayPort=%d, relayID=%s", tcpA.RelayPort(), tcpA.RelayID())

	// Client B allocates TCP
	tcpB, err := cB.AllocateTCP()
	if err != nil {
		log.Fatal("AllocateTCP B failed:", err)
	}
	log.Printf("B: TCP allocated, relayPort=%d, relayID=%s", tcpB.RelayPort(), tcpB.RelayID())

	// Set peer IDs (for permissions)
	// This tells each client who they can communicate with
	cA.SetPeerID(cB.GetClientID())
	cB.SetPeerID(cA.GetClientID())

	// ========== Step 3: B accepts incoming connection ==========

	go func() {
		log.Println("B: Waiting for incoming connection...")

		// Accept() is a long-poll operation
		// It waits until A calls DialTCP()
		connB, err := tcpB.Accept()
		if err != nil {
			log.Println("B: Accept failed:", err)
			return
		}
		log.Println("B: Connection accepted")

		// Continue reading and responding for 20 seconds
		timeout := time.After(20 * time.Second)
		msgCount := 0

		for {
			select {
			case <-timeout:
				log.Printf("B: 20 seconds elapsed, received %d messages", msgCount)
				connB.Close()
				return
			default:
				// Read data from A
				buf := make([]byte, 1024)
				connB.SetReadDeadline(time.Now().Add(2 * time.Second))
				n, err := connB.Read(buf)
				if err != nil {
					if err == io.EOF || err.Error() == "no data available" {
						log.Printf("B: Connection closed after %d messages", msgCount)
						return
					}
					log.Printf("B: Read error: %v", err)
					time.Sleep(100 * time.Millisecond)
					continue
				}
				msgCount++
				log.Printf("B: Received %d bytes: %s (msg #%d)", n, string(buf[:n]), msgCount)

				// Send response back to A
				response := fmt.Sprintf("Hello from B (#%d)", msgCount)
				_, err = connB.Write([]byte(response))
				if err != nil {
					log.Println("B: Write failed:", err)
					return
				}
			}
		}
	}()

	// Give B time to start Accept() long-poll
	time.Sleep(1 * time.Second)

	// ========== Step 4: A dials to B ==========

	log.Println("A: Dialing to B...")
	connA, err := tcpA.DialTCP(cB.GetClientID())
	if err != nil {
		log.Fatal("A: DialTCP failed:", err)
	}
	log.Println("A: Connected to B")

	// ========== Step 5: A sends multiple messages with different lengths for 20 seconds ==========

	timeout := time.After(20 * time.Second)
	msgCount := 0
	ticker := time.NewTicker(500 * time.Millisecond) // Send a message every 500ms
	defer ticker.Stop()

	// Start a goroutine to read responses from B
	go func() {
		for {
			buf := make([]byte, 2048)
			connA.SetReadDeadline(time.Now().Add(2 * time.Second))
			n, err := connA.Read(buf)
			if err != nil {
				if err == io.EOF || err.Error() == "no data available" {
					log.Println("A: Connection closed")
					return
				}
				// log.Printf("A: Read timeout/error: %v", err)
				continue
			}
			log.Printf("A: Received %d bytes: %s", n, string(buf[:n]))
		}
	}()

	for {
		select {
		case <-timeout:
			log.Printf("A: 20 seconds elapsed, sent %d messages", msgCount)
			connA.Close()
			// Wait for B to finish
			time.Sleep(2 * time.Second)
			goto cleanup
		case <-ticker.C:
			// Generate message with different lengths (10 to 500 bytes)
			length := 10 + rand.Intn(490)
			msg := fmt.Sprintf("Message #%d: %s", msgCount, generateRandomString(length))
			_, err = connA.Write([]byte(msg))
			if err != nil {
				log.Println("A: Write failed:", err)
				connA.Close()
				goto cleanup
			}
			log.Printf("A: Sent %d bytes (msg #%d)", len(msg), msgCount)
			msgCount++
		}
	}

cleanup:
	// ========== Step 6: Cleanup ==========

	tcpA.Close()
	tcpB.Close()
	log.Println("Demo complete")
}

// generateRandomString generates a random string of specified length
func generateRandomString(length int) string {
	const charset = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	b := make([]byte, length)
	for i := range b {
		b[i] = charset[rand.Intn(len(charset))]
	}
	return string(b)
}
