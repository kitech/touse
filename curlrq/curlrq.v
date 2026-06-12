// curlrq.v - V 语言绑定
// 通过 C 内联直接调用 curlrq C 库
//
// 使用方式:
//   v -lcurl run curlrq.v
//
// 或在其他 V 文件中:
//   import curlrq

#flag -lcurl
#include "curlrq.h"

// 回调函数类型
pub type Callback = fn (&C.curlrq_response_t, voidptr)

// curlrq_request_t 的 V 封装
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

// 创建引擎
pub fn init(max_concurrent int) &C.curlrq_engine_t {
	return C.curlrq_init(max_concurrent)
}

// 销毁引擎
pub fn cleanup(engine &C.curlrq_engine_t) {
	C.curlrq_cleanup(engine)
}

// 释放响应结果
pub fn response_free(resp &C.curlrq_response_t) {
	C.curlrq_response_free(resp)
}

// 引擎句柄封装
pub struct Engine {
	handle &C.curlrq_engine_t
}

pub fn new_engine(max_concurrent int) ?Engine {
	handle := C.curlrq_init(max_concurrent)
	if handle == 0 {
		return error('curlrq_init failed')
	}
	return Engine{handle}
}

pub fn (e Engine) add(req Request, cb Callback) ? {
	mut creq := C.curlrq_request_t{}
	creq.url = req.url.str
	creq.method = req.method.str
	creq.body = req.body.str
	creq.body_len = req.body_len
	creq.timeout_ms = C.long(req.timeout_ms)
	creq.connect_timeout_ms = C.long(req.connect_timeout_ms)
	creq.max_response_size = C.long(req.max_response_size)
	creq.verify_ssl = if req.verify_ssl { 1 } else { 0 }
	creq.user_data = req.user_data

	// 构造 NULL-terminated headers 数组
	if req.headers.len > 0 {
		n := req.headers.len
		mut hs := []&C.char{len: n + 1}
		for i, h := range req.headers {
			hs[i] = h.str
		}
		unsafe {
			creq.headers = &hs[0]
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

// -------- 引擎默认值设置 --------

pub fn (e Engine) set_max_queue_len(max_len int) {
	C.curlrq_set_max_queue_len(e.handle, max_len)
}

pub fn (e Engine) set_default_timeout_ms(ms int) {
	C.curlrq_set_default_timeout_ms(e.handle, C.long(ms))
}

pub fn (e Engine) set_default_connect_timeout_ms(ms int) {
	C.curlrq_set_default_connect_timeout_ms(e.handle, C.long(ms))
}

pub fn (e Engine) set_default_max_response_size(size int) {
	C.curlrq_set_default_max_response_size(e.handle, C.long(size))
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
