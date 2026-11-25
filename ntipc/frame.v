module ntipc

fn put_u32_le(buf []u8, value u32) {
	buf[0] = u8(value & 0xff)
	buf[1] = u8((value >> 8) & 0xff)
	buf[2] = u8((value >> 16) & 0xff)
	buf[3] = u8((value >> 24) & 0xff)
}

fn get_u32_le(buf []u8) u32 {
	return u32(buf[0]) | (u32(buf[1]) << 8) | (u32(buf[2]) << 16) | (u32(buf[3]) << 24)
}

// Sends one frame: 4-byte little-endian length followed by the payload.
pub fn send_frame(c Conn, payload []u8) ! {
	if payload.len > int(max_frame_size) {
		return error(NtipcError.failed.msg())
	}
	mut head := []u8{len: 4}
	put_u32_le(head, u32(payload.len))
	c.write(head)!
	if payload.len > 0 {
		c.write(payload)!
	}
}

// Receives one frame; an oversized length is a protocol error.
pub fn recv_frame(c Conn) ![]u8 {
	mut head := []u8{len: 4}
	c.read(mut head)!
	n := get_u32_le(head)
	if n > u32(max_frame_size) {
		return error(NtipcError.protocol.msg())
	}
	if n == 0 {
		return []u8{}
	}
	mut payload := []u8{len: int(n)}
	c.read(mut payload)!
	return payload
}
