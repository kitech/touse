module curlrq

fn test_get_request() {
	eng := new_engine(3) or { panic(err) }
	defer {
		eng.cleanup()
	}
	eng.add(Request{
		url: 'https://postman-echo.com/get?q=hello'
		method: 'GET'
		timeout_ms: 10000
		verify_ssl: false
	}, fn (resp &C.curlrq_response_t, _ voidptr) {
		assert resp.http_code == 200
		assert resp.response_body_len > 0
		C.curlrq_response_free(resp)
	}) or { panic(err) }
	eng.wait()
}

fn test_post_request() {
	eng := new_engine(3) or { panic(err) }
	defer {
		eng.cleanup()
	}
	eng.add(Request{
		url: 'https://postman-echo.com/post'
		method: 'POST'
		body: '{"key":"value","num":42}'
		headers: ['Content-Type: application/json', 'Accept: application/json']
		timeout_ms: 10000
		verify_ssl: false
	}, fn (resp &C.curlrq_response_t, _ voidptr) {
		assert resp.http_code == 200
		assert resp.response_body_len > 0
		C.curlrq_response_free(resp)
	}) or { panic(err) }
	eng.wait()
}

fn test_put_request() {
	eng := new_engine(3) or { panic(err) }
	defer {
		eng.cleanup()
	}
	eng.add(Request{
		url: 'https://postman-echo.com/put'
		method: 'PUT'
		body: 'Hello PUT body'
		headers: ['Content-Type: text/plain']
		timeout_ms: 10000
		verify_ssl: false
	}, fn (resp &C.curlrq_response_t, _ voidptr) {
		assert resp.http_code == 200
		assert resp.response_body_len > 0
		C.curlrq_response_free(resp)
	}) or { panic(err) }
	eng.wait()
}

fn test_delete_request() {
	eng := new_engine(3) or { panic(err) }
	defer {
		eng.cleanup()
	}
	eng.add(Request{
		url: 'https://postman-echo.com/delete'
		method: 'DELETE'
		timeout_ms: 10000
		verify_ssl: false
	}, fn (resp &C.curlrq_response_t, _ voidptr) {
		assert resp.http_code == 200
		assert resp.response_body_len > 0
		C.curlrq_response_free(resp)
	}) or { panic(err) }
	eng.wait()
}
