module vrtinfo

import touse.ntipc
import vcp
import vcp.yco
import os
import time

pub struct Server {
pub:
	name string
mut:
	listener ntipc.Listener
	running  bool
}

pub fn start(tag string) !&Server {
	return start_named(service_name(os.getpid(), tag))!
}

fn valid_name(name string) bool {
	if name.len == 0 || name.len > 48 {
		return false
	}
	for c in name.bytes() {
		if !((c >= `A` && c <= `Z`) || (c >= `a` && c <= `z`) || (c >= `0` && c <= `9`) || c == `_` || c == `-`) {
			return false
		}
	}
	return true
}

// 精确绑定指定名字，不拼接 pid；名字直接作为 ntipc socket 名（≤48 位合法字符）
pub fn start_named(name string) !&Server {
	if !valid_name(name) {
		return error('invalid service name: ${name}')
	}
	set_service_name(name)
	mut s := &Server{
		name:     name
		listener: ntipc.listen(name)!
		running:  true
	}
	vcp.info('vrtinfo: server started ${socket_path(name)}')
	yco.gofy(serve_loop, voidptr(s))
	return s
}

pub fn (mut s Server) stop() {
	s.running = false
	s.listener.close()
}

struct ConnBox {
	conn ntipc.Conn
}

pub fn socket_path(name string) string {
	$if windows {
		return name
	} $else {
		return '/tmp/native-ipc-${os.geteuid()}/${name}'
	}
}

// 一帧 = 一次请求，一帧 = 一次响应；语义错误保持连接，协议错误关闭连接
fn handle(raw string) string {
	req := parse_request(raw) or {
		return err_response('', err_bad_request, err.msg())
	}
	if req.cmd !in command_names {
		return err_response(req.id, err_unknown_cmd, 'unknown command: ${req.cmd}')
	}
	mut data := '{}'
	match req.cmd {
		'ping'       { data = ping_data() }
		'caps'       { data = caps_data() }
		'info'       { data = info_data() }
		'gc.stats'   { data = gc_data() }
		'coro.stats' { data = coro_data() }
		'coro.list'  { data = coro_list_data() }
		'threads' {
			data = threads_data() or {
				return err_response(req.id, err_unsupported, err.msg())
			}
		}
		'mem' {
			data = mem_data() or {
				return err_response(req.id, err_unsupported, err.msg())
			}
		}
		else {}
	}
	return ok_response(req.id, data)
}

fn serve_loop(p voidptr) voidptr {
	s := &Server(p)
	yco.register_mycoro()
	for s.running {
		if c := s.listener.accept() {
			vcp.info('vrtinfo: new connection ${s.name} fd=${c.descriptor_of()}')
			mut box := &ConnBox{conn: c}
			yco.gofy(conn_loop, voidptr(box))
		}
		s.listener.keep_name()
		time.sleep(20 * time.millisecond)
	}
	return voidptr(0)
}

fn conn_loop(p voidptr) voidptr {
	box := &ConnBox(p)
	mut conn := box.conn
	fd := conn.descriptor_of()
	yco.register_mycoro()
	defer {
		vcp.info('vrtinfo: connection closed fd=${fd}')
		conn.close()
	}
	for {
		raw := recv_frame(conn, max_request, 0) or { return voidptr(0) }
		if raw.len == 0 {
			return voidptr(0)
		}
		if raw.len > max_request {
			ntipc.send_frame(conn, err_response('', err_too_large, 'request too large').bytes()) or {}
			continue
		}
		resp := handle(raw.bytestr())
		if resp.len > max_response {
			ntipc.send_frame(conn, err_response('', err_too_large, 'response too large').bytes()) or {}
			continue
		}
		ntipc.send_frame(conn, resp.bytes()) or { return voidptr(0) }
	}
	return voidptr(0)
}
