module ntipc

import os
import time

fn accept_wait(l Listener) Conn {
	for i := 0; i < 600; i++ {
		c := l.accept() or { Conn{voidptr(0)} }
		if c.ptr != voidptr(0) {
			return c
		}
		time.sleep(5 * time.millisecond)
	}
	return Conn{voidptr(0)}
}

fn test_roundtrip() {
	name := 'ntipc-v-${os.getpid()}-roundtrip'
	mut l := listen(name) or {
		assert false, err.msg()
		return
	}
	defer { l.close() }

	// connect waits for the listener's hello, which only accept() answers.
	th := spawn connect(name, 2000)
	mut s := accept_wait(l)
	defer { s.close() }
	assert s.ptr != voidptr(0), 'accept failed'

	mut c := th.wait() or {
		assert false, err.msg()
		return
	}
	defer { c.close() }

	msg := 'hello-v-ntipc'.bytes()
	c.write(msg) or {
		assert false, err.msg()
		return
	}
	mut got := []u8{len: msg.len}
	s.read(mut got) or {
		assert false, err.msg()
		return
	}
	assert got == msg

	s.write('ok'.bytes()) or {
		assert false, err.msg()
		return
	}
	mut reply := []u8{len: 2}
	c.read(mut reply) or {
		assert false, err.msg()
		return
	}
	assert reply == 'ok'.bytes()

	assert c.is_open() && s.is_open()
}

fn test_frames() {
	name := 'ntipc-v-${os.getpid()}-frames'
	mut l := listen(name) or {
		assert false, err.msg()
		return
	}
	defer { l.close() }

	th := spawn connect(name, 2000)
	mut s := accept_wait(l)
	defer { s.close() }
	assert s.ptr != voidptr(0), 'accept failed'

	mut c := th.wait() or {
		assert false, err.msg()
		return
	}
	defer { c.close() }

	payload := 'frame payload 123'.bytes()
	send_frame(c, payload) or {
		assert false, err.msg()
		return
	}
	got := recv_frame(s) or {
		assert false, err.msg()
		return
	}
	assert got == payload

	send_frame(c, []u8{}) or {
		assert false, err.msg()
		return
	}
	empty := recv_frame(s) or {
		assert false, err.msg()
		return
	}
	assert empty.len == 0
}

fn test_name_in_use() {
	name := 'ntipc-v-${os.getpid()}-inuse'
	mut first := listen(name) or {
		assert false, err.msg()
		return
	}
	defer { first.close() }

	mut second := listen(name) or {
		assert last_error() == NtipcError.in_use, last_error().msg()
		return
	}
	defer { second.close() }
	assert false, 'second listen should fail'
}

fn test_connect_timeout() {
	mut c := connect('ntipc-v-${os.getpid()}-nobody', 100) or {
		e := last_error()
		assert e == NtipcError.timeout || e == NtipcError.failed, e.msg()
		return
	}
	defer { c.close() }
	assert false, 'connect should fail'
}
