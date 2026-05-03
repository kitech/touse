package main

import (
	"log"
	"os"
	"time"

	"github.com/kitech/touse/hturnal/client"
)

func main() {
	log.SetFlags(log.Lshortfile | log.Ldate | log.Ltime)

	serverURL := "http://localhost:8181"
	if envURL := os.Getenv("SERVER_URL"); envURL != "" {
		serverURL = envURL
	}

	// Create client
	config := client.NewClientConfig(serverURL)
	c, err := client.NewClient(config)
	if err != nil {
		log.Fatal("Failed to create client:", err)
	}

	// Allocate TURN relay
	conn, err := c.Allocate()
	if err != nil {
		log.Fatal("Allocate failed:", err)
	}

	log.Printf("Allocated: clientID=%s, relayPort=%d", c.GetClientID(), c.GetRelayPort())
	log.Printf("PacketConn local addr: %v", conn.LocalAddr())

	// Example: receive data (blocking)
	go func() {
		buf := make([]byte, 65535)
		for {
			n, addr, err := conn.ReadFrom(buf)
			if err != nil {
				log.Println("ReadFrom error:", err)
				return
			}
			log.Printf("Received %d bytes from %v: %s", n, addr, string(buf[:n]))
		}
	}()

	// Example: send data (addr is ignored in current implementation)
	msg := []byte("Hello from hturnal client!")
	_, err = conn.WriteTo(msg, nil)
	if err != nil {
		log.Println("WriteTo error:", err)
	}

	time.Sleep(5 * time.Second)
	conn.Close()
	c.Close()
	log.Println("Client closed")
}
