package turn

import (
	"fmt"
	"io"
	"log"
	"net/http"
	"time"

	"github.com/kitech/touse/hturnal/storage"
)

// NewRelayHandler returns handler for relay port data plane
func NewRelayHandler(store storage.Storage) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		port := parsePortFromPath(r.URL.Path)
		if port == 0 {
			http.Error(w, "Invalid port", http.StatusBadRequest)
			return
		}

		switch r.Method {
		case "POST":
			handleRelaySend(w, r, port, store)
		case "GET":
			handleRelayReceive(w, r, port, store)
		default:
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		}
	}
}

// handleRelaySend handles POST /relay/{port}
// 数据从 sender 发到 peer，存入 peer 的 IncomingQueue
func handleRelaySend(w http.ResponseWriter, r *http.Request, senderPort int, store storage.Storage) {
	senderID := r.Header.Get("X-Hturnal-Client-ID")
	if senderID == "" {
		http.Error(w, "Missing X-Hturnal-Client-ID", http.StatusBadRequest)
		return
	}

	peerID := r.Header.Get("X-Hturnal-Xor-Peer-Address")
	if peerID == "" {
		http.Error(w, "Missing X-Hturnal-Xor-Peer-Address", http.StatusBadRequest)
		return
	}

	// 查找对端的 allocation（数据要发给对端）
	peerAlloc, err := store.GetAllocationByClientID(peerID)
	if err != nil || peerAlloc == nil {
		log.Printf("[RelaySend] Peer not found: peerID=%s, err=%v", peerID, err)
		http.Error(w, "Peer not found", http.StatusNotFound)
		return
	}

	// 读取数据
	data, err := io.ReadAll(io.LimitReader(r.Body, 65536))
	if err != nil || len(data) > 65535 {
		http.Error(w, "Invalid data", http.StatusBadRequest)
		return
	}

	log.Printf("[RelaySend] SenderID=%s, peerID=%s, dataLen=%d, peerRelayPort=%d",
		senderID, peerID, len(data), peerAlloc.RelayPort)

	// 将数据放入对端的 IncomingQueue
	portData := &storage.PortData{
		From:      senderID,
		Data:      data,
		Timestamp: time.Now(),
	}

	select {
	case peerAlloc.IncomingQueue <- portData:
		log.Printf("[RelaySend] Data sent to peer's IncomingQueue, peerID=%s", peerID)
		w.WriteHeader(http.StatusOK)
	default:
		log.Printf("[RelaySend] Queue full for peerID=%s", peerID)
		http.Error(w, "Queue full", http.StatusServiceUnavailable)
	}
}

// handleRelayReceive handles GET /relay/{port}
// 从自己的 IncomingQueue 接收数据
func handleRelayReceive(w http.ResponseWriter, r *http.Request, myPort int, store storage.Storage) {
	receiverID := r.Header.Get("X-Hturnal-Client-ID")
	if receiverID == "" {
		http.Error(w, "Missing X-Hturnal-Client-ID", http.StatusBadRequest)
		return
	}

	// 查找自己的 allocation（通过端口）
	myAlloc, err := store.GetAllocationByPort(myPort)
	if err != nil || myAlloc == nil {
		http.Error(w, "Port not found", http.StatusNotFound)
		return
	}

	// 验证这是否是接收者自己的端口
	if receiverID != myAlloc.ClientID {
		log.Printf("[RelayReceive] Port does not belong to receiver: receiverID=%s, alloc.ClientID=%s",
			receiverID, myAlloc.ClientID)
		http.Error(w, "Port does not belong to you", http.StatusForbidden)
		return
	}

	log.Printf("[RelayReceive] ReceiverID=%s, myPort=%d, queueLen=%d",
		receiverID, myPort, len(myAlloc.IncomingQueue))

	// 解析超时
	timeout := 30
	if t := r.URL.Query().Get("timeout"); t != "" {
		fmt.Sscanf(t, "%d", &timeout)
	}

	deadline := time.Now().Add(time.Duration(timeout) * time.Second)
	for time.Now().Before(deadline) {
		select {
		case portData := <-myAlloc.IncomingQueue:
			if portData != nil {
				log.Printf("[RelayReceive] Received data from %s, len=%d", portData.From, len(portData.Data))
				w.Header().Set("Content-Type", "application/octet-stream")
				w.Header().Set("X-Hturnal-From", portData.From)
				w.Header().Set("X-Hturnal-Timestamp", fmt.Sprintf("%d", portData.Timestamp.Unix()))
				w.Write(portData.Data)
				return
			}
		default:
			time.Sleep(100 * time.Millisecond)
		}
	}

	log.Printf("[RelayReceive] Timeout waiting for data, receiverID=%s", receiverID)
	w.WriteHeader(http.StatusNoContent)
}
