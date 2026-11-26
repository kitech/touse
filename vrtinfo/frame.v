module vrtinfo

import touse.ntipc

const idle_poll_ms = 100
const read_chunk = 256

// 按 ntipc 帧格式读取：4 字节小端长度 + payload。
// 用 read_some + wait_for_work 短轮询，避免 ntipc.read 的 5 秒硬超时把空闲连接关掉。
// idle_limit_ms <= 0 表示无限等待（server 端用）。
fn read_exact(conn ntipc.Conn, mut buf []u8, idle_limit_ms int) ! {
	mut off := 0
	mut idle := 0
	for off < buf.len {
		if !conn.is_open() {
			return error('connection closed')
		}
		mut need := buf.len - off
		if need > read_chunk {
			need = read_chunk
		}
		mut chunk := []u8{len: need}
		n := conn.read_some(mut chunk) or {
			return error('connection closed')
		}
		if n > 0 {
			for i := 0; i < n; i++ {
				buf[off + i] = chunk[i]
			}
			off += n
			idle = 0
			continue
		}
		ntipc.wait_for_work(conn.descriptor_of(), true, false, idle_poll_ms)
		idle += idle_poll_ms
		if idle_limit_ms > 0 && idle >= idle_limit_ms {
			return error('read timeout')
		}
	}
}

pub fn recv_frame(conn ntipc.Conn, max_len int, idle_limit_ms int) ![]u8 {
	mut head := []u8{len: 4}
	read_exact(conn, mut head, idle_limit_ms)!
	n := int(u32(head[0]) | (u32(head[1]) << 8) | (u32(head[2]) << 16) | (u32(head[3]) << 24))
	if n > max_len {
		return error('frame too large')
	}
	if n == 0 {
		return []u8{}
	}
	mut payload := []u8{len: n}
	read_exact(conn, mut payload, idle_limit_ms)!
	return payload
}
