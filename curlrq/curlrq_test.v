module curlrq

struct TestResult {
	id       int
	http_code int
	body_len int
}

struct TestCtx {
	ch chan TestResult
	id int
}

fn on_request_done(resp &C.curlrq_response_t, user_data voidptr) {
	ctx := &TestCtx(user_data)
	ctx.ch <- TestResult{
		id: ctx.id
		http_code: resp.http_code
		body_len: int(resp.response_body_len)
	}
	C.curlrq_response_free(resp)
}

fn test_echo_requests() {
	ch := chan TestResult{cap: 4}

	eng := new_engine(3) or { panic(err) }
	defer {
		eng.cleanup()
	}

	eng.add(Request{
		url: 'https://postman-echo.com/get'
		method: 'GET'
		timeout_ms: 10000
		verify_ssl: false
		user_data: &TestCtx{ch, 1}
	}, on_request_done) or { panic(err) }

	eng.add(Request{
		url: 'https://postman-echo.com/post'
		method: 'POST'
		body: '{"key":"value","num":42}'
		headers: ['Content-Type: application/json', 'Accept: application/json']
		timeout_ms: 10000
		verify_ssl: false
		user_data: &TestCtx{ch, 2}
	}, on_request_done) or { panic(err) }

	eng.add(Request{
		url: 'https://postman-echo.com/put'
		method: 'PUT'
		body: 'Hello PUT body'
		headers: ['Content-Type: text/plain']
		timeout_ms: 10000
		verify_ssl: false
		user_data: &TestCtx{ch, 3}
	}, on_request_done) or { panic(err) }

	eng.add(Request{
		url: 'https://postman-echo.com/delete'
		method: 'DELETE'
		timeout_ms: 10000
		verify_ssl: false
		user_data: &TestCtx{ch, 4}
	}, on_request_done) or { panic(err) }

	eng.wait()

	mut results := []TestResult{}
	for _ in 0 .. 4 {
		results << <-ch
	}

	assert results.len == 4
	for r in results {
		assert r.http_code == 200, 'req ${r.id}: expected 200, got ${r.http_code}'
		assert r.body_len > 0, 'req ${r.id}: body should not be empty'
	}
}
