module ntipc

// Pure C Pipe layer. V links prebuilt .o files when present, otherwise
// compiles the same-named .c sources into its object cache.
#flag -I@DIR/include
#flag @DIR/src/common.o
$if windows {
	#flag @DIR/src/pipe_windows.o
} $else {
	#flag @DIR/src/pipe_posix.o
}

$if linux {
	#flag -lpthread -lrt
} $else $if macos {
	#flag -lpthread
} $else $if windows {
	#flag -ladvapi32
}

#include <ntipc.h>

pub struct Listener {
	ptr voidptr
}

pub struct Conn {
	ptr voidptr
}

pub enum NtipcError {
	none      = C.NTIPC_ERROR_NONE
	failed    = C.NTIPC_ERROR_FAILED
	not_owned = C.NTIPC_ERROR_NOT_OWNED
	protocol  = C.NTIPC_ERROR_PROTOCOL
	in_use    = C.NTIPC_ERROR_IN_USE
	timeout   = C.NTIPC_ERROR_TIMEOUT
}

pub fn (e NtipcError) msg() string {
	return match e {
		.none { 'no error' }
		.failed { 'ntipc operation failed' }
		.not_owned { 'name belongs to another user' }
		.protocol { 'protocol mismatch' }
		.in_use { 'name already has a listener' }
		.timeout { 'ntipc operation timed out' }
	}
}

pub const (
	protocol_version = C.NTIPC_PROTOCOL_VERSION
	max_frame_size   = C.NTIPC_MAX_FRAME_SIZE
)

fn C.ntipc_listen(name &char) voidptr
fn C.ntipc_accept(listener voidptr) voidptr
fn C.ntipc_connect(name &char, timeout_ms int) voidptr
fn C.ntipc_close(handle voidptr)
fn C.ntipc_bytes_available(conn voidptr) int
fn C.ntipc_read(conn voidptr, buf &u8, size int) int
fn C.ntipc_read_some(conn voidptr, buf &u8, size int) int
fn C.ntipc_write_some(conn voidptr, buf &u8, size int) int
fn C.ntipc_write(conn voidptr, buf &u8, size int) bool
fn C.ntipc_is_open(conn voidptr) bool
fn C.ntipc_keep_name(handle voidptr)
fn C.ntipc_descriptor_of(handle voidptr) int
fn C.ntipc_wait_for_work(fd int, read bool, write bool, timeout_ms int) bool
fn C.ntipc_last_error() int

pub fn last_error() NtipcError {
	return NtipcError(C.ntipc_last_error())
}

fn err_here() string {
	e := last_error()
	if e == NtipcError.none {
		return error(NtipcError.failed.msg()).msg()
	}
	return e.msg()
}

pub fn listen(name string) !Listener {
	h := C.ntipc_listen(name.str)
	if h == voidptr(0) {
		return error(last_error().msg())
	}
	return Listener{h}
}

pub fn connect(name string, timeout_ms int) !Conn {
	h := C.ntipc_connect(name.str, timeout_ms)
	if h == voidptr(0) {
		return error(last_error().msg())
	}
	return Conn{h}
}

pub fn (l Listener) accept() !Conn {
	h := C.ntipc_accept(l.ptr)
	if h == voidptr(0) {
		return error(last_error().msg())
	}
	return Conn{h}
}

pub fn (mut l Listener) close() {
	if l.ptr != voidptr(0) {
		C.ntipc_close(l.ptr)
		l.ptr = voidptr(0)
	}
}

pub fn (mut c Conn) close() {
	if c.ptr != voidptr(0) {
		C.ntipc_close(c.ptr)
		c.ptr = voidptr(0)
	}
}

pub fn (c Conn) bytes_available() int {
	return C.ntipc_bytes_available(c.ptr)
}

pub fn (c Conn) is_open() bool {
	return C.ntipc_is_open(c.ptr)
}

pub fn (c Conn) read(mut buf []u8) !int {
	if buf.len == 0 {
		return error(NtipcError.failed.msg())
	}
	if C.ntipc_read(c.ptr, buf.data, buf.len) != 0 {
		return error(err_here())
	}
	return buf.len
}

pub fn (c Conn) read_some(mut buf []u8) !int {
	if buf.len == 0 {
		return error(NtipcError.failed.msg())
	}
	n := C.ntipc_read_some(c.ptr, buf.data, buf.len)
	if n < 0 {
		return error(err_here())
	}
	return n
}

pub fn (c Conn) write(buf []u8) ! {
	if buf.len == 0 {
		return
	}
	if !C.ntipc_write(c.ptr, buf.data, buf.len) {
		return error(err_here())
	}
}

pub fn (c Conn) write_some(buf []u8) !int {
	if buf.len == 0 {
		return 0
	}
	n := C.ntipc_write_some(c.ptr, buf.data, buf.len)
	if n < 0 {
		return error(err_here())
	}
	return n
}

pub fn (l Listener) keep_name() {
	C.ntipc_keep_name(l.ptr)
}

pub fn (c Conn) keep_name() {
	C.ntipc_keep_name(c.ptr)
}

pub fn (l Listener) descriptor_of() int {
	return C.ntipc_descriptor_of(l.ptr)
}

pub fn (c Conn) descriptor_of() int {
	return C.ntipc_descriptor_of(c.ptr)
}

pub fn wait_for_work(fd int, read bool, write bool, timeout_ms int) bool {
	return C.ntipc_wait_for_work(fd, read, write, timeout_ms)
}

pub fn raw(c Conn) voidptr {
	return c.ptr
}
