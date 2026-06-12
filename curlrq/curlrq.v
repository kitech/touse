module curlrq

#flag -lcurl
#flag @DIR/curlrq.o
#include "@DIR/curlrq.h"

@[typedef]
pub struct C.curlrq_engine_t {}

@[typedef]
pub struct C.curlrq_response_t {
    http_code            int
    total_time_ms        int
    response_body        &C.char
    response_body_len    usize
    response_headers     &C.char
    response_headers_len usize
    effective_url        &C.char
    curl_code            int
    error_msg            &C.char
}

@[typedef]
pub struct C.curlrq_request_t {
    url                 &C.char
    method              &C.char
    body                &C.char
    body_len            usize
    headers             &&C.char
    timeout_ms          int
    connect_timeout_ms  int
    max_response_size   int
    verify_ssl          int
    user_data           voidptr
}

pub type Callback = fn (&C.curlrq_response_t, voidptr)

fn C.curlrq_init(int) &C.curlrq_engine_t
fn C.curlrq_cleanup(&C.curlrq_engine_t)
fn C.curlrq_add(&C.curlrq_engine_t, &C.curlrq_request_t, Callback) int
fn C.curlrq_set_max_queue_len(&C.curlrq_engine_t, int)
fn C.curlrq_set_default_timeout_ms(&C.curlrq_engine_t, int)
fn C.curlrq_set_default_connect_timeout_ms(&C.curlrq_engine_t, int)
fn C.curlrq_set_default_max_response_size(&C.curlrq_engine_t, int)
fn C.curlrq_set_default_verify_ssl(&C.curlrq_engine_t, int)
fn C.curlrq_set_default_header(&C.curlrq_engine_t, &C.char)
fn C.curlrq_wait(&C.curlrq_engine_t)
fn C.curlrq_pending(&C.curlrq_engine_t) int
fn C.curlrq_active(&C.curlrq_engine_t) int
fn C.curlrq_response_free(&C.curlrq_response_t)

pub struct Request {
pub:
	url                string
	method             string
	body               string
	body_len           usize
	headers            []string
	timeout_ms         int
	connect_timeout_ms int
	max_response_size  int
	verify_ssl         bool
	user_data          voidptr
}

pub struct Engine {
	handle &C.curlrq_engine_t
}

pub fn new_engine(max_concurrent int) !Engine {
	handle := C.curlrq_init(max_concurrent)
	if handle == 0 {
		return error('curlrq_init failed')
	}
	return Engine{handle}
}

pub fn (e Engine) add(req Request, cb Callback) ! {
    mut creq := C.curlrq_request_t{
        url: 0
        method: 0
        body: 0
        headers: 0
    }
    creq.url = req.url.str
    creq.method = req.method.str
    creq.body = req.body.str
    creq.body_len = req.body_len
    creq.timeout_ms = req.timeout_ms
    creq.connect_timeout_ms = req.connect_timeout_ms
    creq.max_response_size = req.max_response_size
    creq.verify_ssl = if req.verify_ssl { 1 } else { 0 }
    creq.user_data = req.user_data

	if req.headers.len > 0 {
		n := req.headers.len
		mut hs := []&char{len: n + 1}
		for i, h in req.headers {
			hs[i] = &char(h.str)
		}
		unsafe {
			creq.headers = hs.data
		}
	}

	ret := C.curlrq_add(e.handle, &creq, cb)
	if ret != 0 {
		return error('curlrq_add failed')
	}
}

pub fn (e Engine) wait() {
	C.curlrq_wait(e.handle)
}

pub fn (e Engine) pending() int {
	return C.curlrq_pending(e.handle)
}

pub fn (e Engine) active() int {
	return C.curlrq_active(e.handle)
}

pub fn (e Engine) response_free(resp &C.curlrq_response_t) {
	C.curlrq_response_free(resp)
}

pub fn (e Engine) set_max_queue_len(max_len int) {
	C.curlrq_set_max_queue_len(e.handle, max_len)
}

pub fn (e Engine) set_default_timeout_ms(ms int) {
	C.curlrq_set_default_timeout_ms(e.handle, ms)
}

pub fn (e Engine) set_default_connect_timeout_ms(ms int) {
	C.curlrq_set_default_connect_timeout_ms(e.handle, ms)
}

pub fn (e Engine) set_default_max_response_size(size int) {
	C.curlrq_set_default_max_response_size(e.handle, size)
}

pub fn (e Engine) set_default_verify_ssl(verify bool) {
	C.curlrq_set_default_verify_ssl(e.handle, if verify { 1 } else { 0 })
}

pub fn (e Engine) set_default_header(header string) {
	C.curlrq_set_default_header(e.handle, header.str)
}

pub fn (e Engine) cleanup() {
	C.curlrq_cleanup(e.handle)
}
