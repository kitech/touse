package main

import (
	"encoding/base64"
	"flag"
	"log"
	"os"
	"time"

	"github.com/kitech/touse/hturnal/client"
)

func main() {
	// Log configuration
	log.SetFlags(log.Lshortfile | log.Ldate | log.Ltime)

	// Server URL configuration
	serverURL := flag.String("server", "", "Server URL (default http://localhost:8181)")
	flag.Parse()

	if *serverURL == "" {
		if envURL := os.Getenv("SERVER_URL"); envURL != "" {
			*serverURL = envURL
		} else {
			*serverURL = "http://localhost:8181"
		}
	}

	// Create client
	c := client.NewClient(*serverURL)
	log.Printf("Using server: %s", *serverURL)

	// 1. STUN example - Get public address
	log.Println("=== STUN Binding Example ===")
	binding, err := c.GetPublicAddress("node_a")
	if err != nil {
		log.Fatal("STUN binding failed:", err)
	}
	log.Printf("Public address: %s", binding.MappedAddress)

	// 2. STUN example - Check NAT type
	log.Println("=== STUN NAT Check Example ===")
	natResp, err := c.CheckNATType("node_a")
	if err != nil {
		log.Fatal("NAT check failed:", err)
	}
	log.Printf("NAT Type: %s, Public IP: %s", natResp.NATType, natResp.PublicIP)

	// 3. TURN example - Allocate relay
	log.Println("=== TURN Allocate Example ===")
	alloc, err := c.Allocate("node_a")
	if err != nil {
		log.Fatal("TURN allocate failed:", err)
	}
	log.Printf("Allocated relay: %s, Address: %s, Lifetime: %d", alloc.RelayID, alloc.RelayAddress, alloc.Lifetime)

	// 4. TURN example - Add permission then send message
	log.Println("=== TURN Send Example ===")
	err = c.AddPermission([]string{"node_b"})
	if err != nil {
		log.Fatal("Add permission failed:", err)
	}
	msg := []byte("Hello from node_a via hturnal!")
	err = c.SendToPeer("node_b", msg)
	if err != nil {
		log.Fatal("Send failed:", err)
	}
	log.Println("Message sent to node_b!")

	// 5. TURN example - Receive messages (long-poll)
	log.Println("=== TURN Receive Example ===")
	go func() {
		for {
			messages, err := c.Receive(30)
			if err != nil {
				log.Println("Receive error:", err)
				continue
			}
			for _, m := range messages {
				data, _ := base64.StdEncoding.DecodeString(m.Data)
				log.Printf("Received from %s: %s", m.From, string(data))
			}
		}
	}()

	// 6. Stream example (optional)
	log.Println("=== Stream Example ===")
	streamResp, err := c.StartStream("node_b")
	if err != nil {
		log.Fatal("Stream start failed:", err)
	}
	log.Printf("Stream started: %s, Chunk size: %d", streamResp.StreamID, streamResp.ChunkSize)

	// Send a chunk
	chunkData := []byte("Stream chunk data example")
	err = c.SendChunk(streamResp.StreamID, 0, chunkData)
	if err != nil {
		log.Fatal("Send chunk failed:", err)
	}
	log.Println("Stream chunk sent!")

	// Receive chunks
	chunksResp, err := c.ReceiveChunks(streamResp.StreamID, 30)
	if err != nil {
		log.Fatal("Receive chunks failed:", err)
	}
			for _, chunk := range chunksResp.Chunks {
				data, _ := base64.StdEncoding.DecodeString(chunk.Data)
				log.Printf("Received chunk %d: %s", chunk.ChunkSeq, string(data))
			}

	// End stream
	err = c.EndStream(streamResp.StreamID)
	if err != nil {
		log.Fatal("End stream failed:", err)
	}
	log.Println("Stream ended!")

	// Keep running to allow receiving messages
	log.Println("Client running... (Ctrl+C to stop)")
	time.Sleep(1 * time.Hour)
}
