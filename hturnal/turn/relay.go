package turn

import (
	"fmt"
	"io"
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

// handleRelaySend handles POST /relay/{port} (发送数据，模拟Send Indication)
func handleRelaySend(w http.ResponseWriter, r *http.Request, port int, store storage.Storage) {
	// 获取发送方标识
	senderID := r.Header.Get("X-Hturnal-Client-ID")
	if senderID == "" {
		http.Error(w, "Missing X-Hturnal-Client-ID", http.StatusBadRequest)
		return
	}

	// 获取对端地址（XOR-PEER-ADDRESS模拟）
	peerAddr := r.Header.Get("X-Hturnal-Xor-Peer-Address")
	if peerAddr == "" {
		http.Error(w, "Missing X-Hturnal-Xor-Peer-Address", http.StatusBadRequest)
		return
	}

	// 查找该端口对应的allocation
	alloc, err := store.GetAllocationByPort(port)
	if err != nil || alloc == nil {
		http.Error(w, "Port not found", http.StatusNotFound)
		return
	}

	// 读取原始二进制数据（限制64KB）
	data, err := io.ReadAll(io.LimitReader(r.Body, 65536))
	if err != nil || len(data) > 65535 {
		http.Error(w, "Invalid data", http.StatusBadRequest)
		return
	}

	alloc.Mu.Lock()

	// 自动检测方向：Owner还是Peer？
	var targetChan chan *storage.PortData

	if senderID == alloc.ClientID {
		// Owner发送 → 验证peerAddr是否在Permissions中
		if !alloc.Permissions[peerAddr] {
			alloc.Mu.Unlock()
			http.Error(w, "Peer not permitted", http.StatusForbidden)
			return
		}
		targetChan = alloc.OutgoingQueue // 让Peer接收
	} else if alloc.Permissions[senderID] {
		// Peer发送 → 验证peerAddr是否是Owner
		if peerAddr != alloc.ClientID {
			alloc.Mu.Unlock()
			http.Error(w, "Invalid peer address", http.StatusForbidden)
			return
		}
		targetChan = alloc.IncomingQueue // 让Owner接收
	} else {
		alloc.Mu.Unlock()
		http.Error(w, "Permission denied", http.StatusForbidden)
		return
	}
	alloc.Mu.Unlock()

	// 构造PortData并尝试发送到channel（非阻塞）
	portData := &storage.PortData{
		From:      senderID,
		Data:      data,
		Timestamp: time.Now(),
	}

	select {
	case targetChan <- portData:
		w.WriteHeader(http.StatusOK)
	default:
		http.Error(w, "Queue full", http.StatusServiceUnavailable)
	}
}

// handleRelayReceive handles GET /relay/{port} (接收数据，长轮询，模拟Data Indication)
func handleRelayReceive(w http.ResponseWriter, r *http.Request, port int, store storage.Storage) {
	// 获取接收方标识
	receiverID := r.Header.Get("X-Hturnal-Client-ID")
	if receiverID == "" {
		http.Error(w, "Missing X-Hturnal-Client-ID", http.StatusBadRequest)
		return
	}

	// 查找该端口对应的allocation
	alloc, err := store.GetAllocationByPort(port)
	if err != nil || alloc == nil {
		http.Error(w, "Port not found", http.StatusNotFound)
		return
	}

	// 解析超时参数
	timeout := 30
	if t := r.URL.Query().Get("timeout"); t != "" {
		fmt.Sscanf(t, "%d", &timeout)
	}

	deadline := time.Now().Add(time.Duration(timeout) * time.Second)
	for time.Now().Before(deadline) {
		alloc.Mu.Lock()
		var targetChan chan *storage.PortData

		// 自动检测：Owner还是Peer？
		if receiverID == alloc.ClientID {
			// Owner接收 → 从IncomingQueue取（Peer发的）
			targetChan = alloc.IncomingQueue
		} else if alloc.Permissions[receiverID] {
			// Peer接收 → 从OutgoingQueue取（Owner发的）
			targetChan = alloc.OutgoingQueue
		} else {
			alloc.Mu.Unlock()
			http.Error(w, "Permission denied", http.StatusForbidden)
			return
		}
		alloc.Mu.Unlock()

		// 非阻塞读取
		select {
		case portData := <-targetChan:
			if portData != nil {
				// 返回原始二进制数据 + 元信息头
				w.Header().Set("Content-Type", "application/octet-stream")
				w.Header().Set("X-Hturnal-From", portData.From) // 发送方
				w.Header().Set("X-Hturnal-Timestamp", fmt.Sprintf("%d", portData.Timestamp.Unix()))
				w.Write(portData.Data)
				return
			}
		default:
			// 没有数据，继续等待
		}

		time.Sleep(100 * time.Millisecond)
	}

	// 超时
	w.WriteHeader(http.StatusNoContent)
}
