package turn

import (
	"fmt"
	"net"
	"net/http"
	"strconv"
	"strings"
	"sync"
)

// ========== 端口池1：按IP管理（用于ClientID）==========
type IPPortPool struct {
	mu       sync.Mutex
	maxPorts int // 每IP最大端口数 = 1024
	pools    map[string]*PerIPPool
}

type PerIPPool struct {
	allocated   map[int]bool
	nextPort   int
}

var globalIPPortPool = &IPPortPool{
	maxPorts: 1024,
	pools:    make(map[string]*PerIPPool),
}

// AllocateClientPort 为指定IP分配端口，返回端口号和clientID（格式 "ip:port"）
func (p *IPPortPool) AllocateClientPort(clientIP string) (int, string, error) {
	p.mu.Lock()
	defer p.mu.Unlock()

	pool, ok := p.pools[clientIP]
	if !ok {
		pool = &PerIPPool{
			allocated: make(map[int]bool),
			nextPort:  1,
		}
		p.pools[clientIP] = pool
	}

	if len(pool.allocated) >= p.maxPorts {
		return 0, "", fmt.Errorf("IP %s exceeded max ports %d", clientIP, p.maxPorts)
	}

	start := pool.nextPort
	for {
		port := pool.nextPort
		if port > 1024 {
			pool.nextPort = 1
			continue
		}
		if !pool.allocated[port] {
			pool.allocated[port] = true
			clientID := fmt.Sprintf("%s:%d", clientIP, port)
			pool.nextPort = port + 1
			if pool.nextPort > 1024 {
				pool.nextPort = 1
			}
			return port, clientID, nil
		}
		pool.nextPort++
		if pool.nextPort > 1024 {
			pool.nextPort = 1
		}
		if pool.nextPort == start {
			break
		}
	}
	return 0, "", fmt.Errorf("no available client ports for IP %s", clientIP)
}

// ReleaseClientPort 释放指定IP的端口
func (p *IPPortPool) ReleaseClientPort(clientIP string, port int) {
	p.mu.Lock()
	defer p.mu.Unlock()
	if pool, ok := p.pools[clientIP]; ok {
		delete(pool.allocated, port)
		if len(pool.allocated) == 0 {
			delete(p.pools, clientIP)
		}
	}
}

// ========== 端口池2：全局管理（用于relay_port）==========
type GlobalRelayPortPool struct {
	mu       sync.Mutex
	allocated map[int]bool
	nextPort  int
}

var globalRelayPortPool = &GlobalRelayPortPool{
	allocated: make(map[int]bool),
	nextPort:  1,
}

// AllocateRelayPort 分配全局relay端口（1-65535）
func (p *GlobalRelayPortPool) Allocate() (int, error) {
	p.mu.Lock()
	defer p.mu.Unlock()

	start := p.nextPort
	for {
		port := p.nextPort
		if port > 65535 {
			p.nextPort = 1
			continue
		}
		if !p.allocated[port] {
			p.allocated[port] = true
			p.nextPort = port + 1
			if p.nextPort > 65535 {
				p.nextPort = 1
			}
			return port, nil
		}
		p.nextPort++
		if p.nextPort > 65535 {
			p.nextPort = 1
		}
		if p.nextPort == start {
			break
		}
	}
	return 0, fmt.Errorf("no available relay ports")
}

// ReleaseRelayPort 释放全局relay端口
func (p *GlobalRelayPortPool) Release(port int) {
	p.mu.Lock()
	defer p.mu.Unlock()
	delete(p.allocated, port)
}

// getClientIP 从HTTP请求获取客户端IP（按优先级）
func getClientIP(r *http.Request) string {
	// 1. X-Forwarded-For
	if xff := r.Header.Get("X-Forwarded-For"); xff != "" {
		parts := strings.Split(xff, ",")
		return strings.TrimSpace(parts[0])
	}
	// 2. X-Real-IP
	if xrip := r.Header.Get("X-Real-IP"); xrip != "" {
		return xrip
	}
	// 3. RemoteAddr（取IP部分，忽略端口）
	if host, _, err := net.SplitHostPort(r.RemoteAddr); err == nil {
		return host
	}
	return r.RemoteAddr
}

// parsePortFromPath 从/relay/123提取端口号
func parsePortFromPath(path string) int {
	// 简单实现：从路径中提取最后一个数字
	parts := strings.Split(path, "/")
	for i := len(parts) - 1; i >= 0; i-- {
		if p, err := strconv.Atoi(parts[i]); err == nil {
			return p
		}
	}
	return 0
}
