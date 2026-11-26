module vrtinfo

import touse.ntipc

pub struct Client {
pub:
	name string
mut:
	conn ntipc.Conn
}

pub fn connect(name string, timeout_ms int) !Client {
	c := ntipc.connect(name, timeout_ms)!
	return Client{ name: name, conn: c }
}

pub fn (mut c Client) close() {
	c.conn.close()
}

pub fn (c Client) is_open() bool {
	return c.conn.is_open()
}

pub fn (c Client) request(id string, cmd string, args string) !Reply {
	raw := '{"v":${version},"id":${jstr(id)},"cmd":${jstr(cmd)},"args":${args}}'
	ntipc.send_frame(c.conn, raw.bytes())!
	resp := recv_frame(c.conn, max_response, 30000)!
	return parse_reply(resp.bytestr())!
}
