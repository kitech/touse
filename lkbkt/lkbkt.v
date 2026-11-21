// V binding for lkbkt (safe wrapper, module `lkbkt`, same name as the C3
// binding).
//
// Runnable checks live in demo.vsh; run them with `make v-check`, which
// builds liblkbkt.a and passes the required -ldflags.
//
// To use as a library: import lkbkt and call bucket_new / check / free.

module lkbkt

import time

#flag -I @DIR/
#flag @DIR/leakybucket.o

// C functions are declared explicitly; no header include is required.
fn C.lkbkt_new(rate u32, burst u32, delay u32, max_keys usize) voidptr
fn C.lkbkt_free(handle voidptr)
fn C.lkbkt_check(handle voidptr, key &char, keylen usize, now_ms u64, delay_ms &u32) int
fn C.lkbkt_expire(handle voidptr, now_ms u64) usize
fn C.lkbkt_size(handle voidptr) usize

pub const nodelay = u32(0xFFFF_FFFF)

pub enum Result {
	pass   = 0
	delay  = 1
	reject = 2
	error  = 3
}

pub struct Decision {
pub:
	result   Result
	delay_ms u32
}

pub struct Bucket {
mut:
	handle voidptr
}

pub fn bucket_new(rate u32, burst u32, delay u32, max_keys usize) !Bucket {
	if rate == 0 || max_keys == 0 {
		return error('invalid rate or max_keys')
	}
	handle := C.lkbkt_new(rate, burst, delay, max_keys)
	if isnil(handle) {
		return error('lkbkt_new failed')
	}
	return Bucket{
		handle: handle
	}
}

pub fn (b &Bucket) free() {
	if !isnil(b.handle) {
		C.lkbkt_free(b.handle)
	}
}

pub fn (b &Bucket) check(key string, now_ms u64) Decision {
	if isnil(b.handle) {
		return Decision{
			result: .error
			delay_ms: 0
		}
	}
	mut delay_ms := u32(0)
	r := C.lkbkt_check(b.handle, key.str, key.len, now_ms, &delay_ms)
	return Decision{
		result: unsafe { Result(int(r)) }
		delay_ms: delay_ms
	}
}

pub fn (b &Bucket) expire(now_ms u64) usize {
	if isnil(b.handle) {
		return 0
	}
	return C.lkbkt_expire(b.handle, now_ms)
}

pub fn (b &Bucket) size() usize {
	if isnil(b.handle) {
		return 0
	}
	return C.lkbkt_size(b.handle)
}

pub fn now_ms() u64 {
	return u64(time.ticks())
}
