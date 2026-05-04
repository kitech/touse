package main;

import (
	"flag"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/kitech/touse/hturnal/discovery"
	"github.com/kitech/touse/hturnal/storage"
	"github.com/kitech/touse/hturnal/stun"
	"github.com/kitech/touse/hturnal/turn"
)

func main() {
	// Log configuration
	logFlags := flag.Int("log-flags", 0, "Log flags (default: Lshortfile|Ldate|Ltime=11)")
	portFlag := flag.String("port", "", "Server port (default 8181)")
	flag.Parse()

	if *logFlags == 0 {
		log.SetFlags(log.Lshortfile | log.Ldate | log.Ltime)
	} else {
		log.SetFlags(*logFlags)
	}

	// Storage initialization (compilation tag controlled)
	store := storage.NewStorage()
	go store.StartCleanup(1 * time.Minute)

	// Setup routes
	setupRoutes(store)

	port := *portFlag
	if port == "" {
		port = os.Getenv("PORT")
	}
	if port == "" {
		port = "8181"
	}
	addr := ":" + port

	log.Printf("Starting hturnal server on %s", addr)
	log.Fatal(http.ListenAndServe(addr, nil))
}

func setupRoutes(store storage.Storage) {
	// STUN endpoints
	http.HandleFunc("/stun/binding", wrap(stun.NewBindingHandler(store)))
	http.HandleFunc("/stun/binding-to", wrap(stun.NewBindingRequestToHandler(store)))
	http.HandleFunc("/stun/nat-check", wrap(stun.NewNATCheckHandler(store)))

	// TURN endpoints
	http.HandleFunc("/turn/allocate", wrap(turn.NewAllocateHandler(store)))
	http.HandleFunc("/turn/permission", wrap(turn.NewPermissionHandler(store)))
	http.HandleFunc("/turn/send", wrap(turn.NewSendHandler(store)))
	http.HandleFunc("/turn/receive", wrap(turn.NewReceiveHandler(store)))
	http.HandleFunc("/turn/refresh", wrap(turn.NewRefreshHandler(store)))
	http.HandleFunc("/turn/deallocate", wrap(turn.NewDeallocateHandler(store)))

	// TURN stream endpoints
	http.HandleFunc("/turn/stream/start", wrap(turn.NewStreamStartHandler(store)))
	http.HandleFunc("/turn/stream/send", wrap(turn.NewStreamSendHandler(store)))
	http.HandleFunc("/turn/stream/receive", wrap(turn.NewStreamReceiveHandler(store)))
	http.HandleFunc("/turn/stream/end", wrap(turn.NewStreamEndHandler(store)))

	// Discovery endpoint
	http.HandleFunc("/discovery/servers", wrap(discovery.NewHandler(store)))

	// Relay endpoint (pseudo-port data plane)
	http.HandleFunc("/relay/", wrap(turn.NewRelayHandler(store)))

	// TURN TCP endpoints (Phase 6)
	http.HandleFunc("/turn/tcp/allocate", wrap(turn.NewTCPAllocateHandler(store)))
	http.HandleFunc("/turn/tcp/dial", wrap(turn.NewTCPDialHandler(store)))
	http.HandleFunc("/turn/tcp/accept", wrap(turn.NewTCPAcceptHandler(store)))
	http.HandleFunc("/turn/tcp/deallocate", wrap(turn.NewTCPDeallocateHandler(store)))

	// TCP Relay endpoint
	http.HandleFunc("/relay/tcp/", wrap(turn.NewTCPRelayHandler(store)))
}

// wrap adds common middleware: CORS, logging, content type
func wrap(h http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()

		// CORS headers
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type")

		if r.Method == "OPTIONS" {
			w.WriteHeader(http.StatusOK)
			return
		}

		// JSON content type
		w.Header().Set("Content-Type", "application/json")

		// Execute handler
		h(w, r)

		// Log request (uses log flags set globally)
		log.Printf("%s %s %v", r.Method, r.URL.Path, time.Since(start))
	}
}
