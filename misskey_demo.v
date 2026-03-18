module main

import os

#flag linux -I./src
#flag linux -L. -lmisskey -lcurl

struct C.MisskeyClient {}

fn C.misskey_client_new(host &char) &C.MisskeyClient
fn C.misskey_client_free(client &C.MisskeyClient)
fn C.misskey_client_set_token(client &C.MisskeyClient, token &char)
fn C.misskey_request(client &C.MisskeyClient, endpoint &char, body &char, response &&char) int
fn C.misskey_meta(client &C.MisskeyClient, response &&char) int
fn C.misskey_notes_timeline(client &C.MisskeyClient, limit int, local int, response &&char) int
fn C.misskey_i_notifications(client &C.MisskeyClient, limit int, response &&char) int
fn C.misskey_drive(client &C.MisskeyClient, response &&char) int
fn C.misskey_drive_files(client &C.MisskeyClient, limit int, folder_id int, response &&char) int
fn C.misskey_drive_files_find(client &C.MisskeyClient, hash &char, response &&char) int
fn C.misskey_drive_files_show(client &C.MisskeyClient, file_id &char, url &char, response &&char) int
fn C.misskey_drive_files_upload_from_url(client &C.MisskeyClient, url &char, folder_id &char, is_sensitive int, comment &char, response &&char) int
fn C.misskey_drive_folders(client &C.MisskeyClient, limit int, folder_id &char, response &&char) int
fn C.misskey_translate(client &C.MisskeyClient, text &char, source_lang &char, target_lang &char, response &&char) int
fn C.misskey_request_set_debug(client &C.MisskeyClient, enable int)
fn C.misskey_free_string(client &C.MisskeyClient, str &char)
fn C.misskey_error_str(err int) &char

struct Client {
	c_client &C.MisskeyClient
}

fn new_client(host string) !Client {
	c_client := C.misskey_client_new(&char(host.str))
	if c_client == unsafe { nil } {
		return error('failed to create client')
	}
	return Client{c_client}
}

fn (mut c Client) free() {
	C.misskey_client_free(c.c_client)
}

fn (mut c Client) set_token(token string) {
	C.misskey_client_set_token(c.c_client, &char(token.str))
}

fn (mut c Client) set_debug(enable bool) {
	C.misskey_request_set_debug(c.c_client, if enable { 1 } else { 0 })
}

fn (c &Client) do_request(endpoint string, body string) !string {
	mut response := &char(0)
	ret := C.misskey_request(c.c_client, &char(endpoint.str), &char(body.str), &response)
	if ret != 0 {
		return error('request failed: err=${ret}')
	}
	result := unsafe { cstring_to_vstring(response) }
	C.misskey_free_string(c.c_client, response)
	return result
}

fn (mut c Client) meta() !string {
	return c.do_request('meta', '{"detail":false}')
}

fn (mut c Client) notes_timeline(limit int, local bool) !string {
	local_val := if local { 1 } else { 0 }
	mut response := &char(0)
	ret := C.misskey_notes_timeline(c.c_client, limit, local_val, &response)
	if ret != 0 {
		return error('notes_timeline failed')
	}
	result := unsafe { cstring_to_vstring(response) }
	C.misskey_free_string(c.c_client, response)
	return result
}

fn (mut c Client) i_notifications(limit int) !string {
	mut response := &char(0)
	ret := C.misskey_i_notifications(c.c_client, limit, &response)
	if ret != 0 {
		return error('i_notifications failed')
	}
	result := unsafe { cstring_to_vstring(response) }
	C.misskey_free_string(c.c_client, response)
	return result
}

fn (mut c Client) drive() !string {
	mut response := &char(0)
	ret := C.misskey_drive(c.c_client, &response)
	if ret != 0 {
		return error('drive failed')
	}
	result := unsafe { cstring_to_vstring(response) }
	C.misskey_free_string(c.c_client, response)
	return result
}

fn (mut c Client) drive_files(limit int, folder_id int) !string {
	mut response := &char(0)
	ret := C.misskey_drive_files(c.c_client, limit, folder_id, &response)
	if ret != 0 {
		return error('drive_files failed')
	}
	result := unsafe { cstring_to_vstring(response) }
	C.misskey_free_string(c.c_client, response)
	return result
}

fn (mut c Client) drive_files_find(hash string) !string {
	mut response := &char(0)
	ret := C.misskey_drive_files_find(c.c_client, &char(hash.str), &response)
	if ret != 0 {
		return error('drive_files_find failed')
	}
	result := unsafe { cstring_to_vstring(response) }
	C.misskey_free_string(c.c_client, response)
	return result
}

fn (mut c Client) drive_files_show(file_id string, url string) !string {
	file_id_cstr := if file_id.len > 0 { &char(file_id.str) } else { voidptr(0) }
	url_cstr := if url.len > 0 { &char(url.str) } else { voidptr(0) }
	mut response := &char(0)
	ret := C.misskey_drive_files_show(c.c_client, file_id_cstr, url_cstr, &response)
	if ret != 0 {
		return error('drive_files_show failed')
	}
	result := unsafe { cstring_to_vstring(response) }
	C.misskey_free_string(c.c_client, response)
	return result
}

fn (mut c Client) drive_files_upload_from_url(url string, folder_id string, is_sensitive bool, comment string) !string {
	folder_cstr := if folder_id.len > 0 { &char(folder_id.str) } else { voidptr(0) }
	comment_cstr := if comment.len > 0 { &char(comment.str) } else { voidptr(0) }
	sensitive_val := if is_sensitive { 1 } else { 0 }
	mut response := &char(0)
	ret := C.misskey_drive_files_upload_from_url(c.c_client, &char(url.str), folder_cstr, sensitive_val, comment_cstr, &response)
	if ret != 0 {
		return error('drive_files_upload_from_url failed')
	}
	result := unsafe { cstring_to_vstring(response) }
	C.misskey_free_string(c.c_client, response)
	return result
}

fn (mut c Client) drive_folders(limit int, folder_id string) !string {
	folder_cstr := if folder_id.len > 0 { &char(folder_id.str) } else { voidptr(0) }
	mut response := &char(0)
	ret := C.misskey_drive_folders(c.c_client, limit, folder_cstr, &response)
	if ret != 0 {
		return error('drive_folders failed')
	}
	result := unsafe { cstring_to_vstring(response) }
	C.misskey_free_string(c.c_client, response)
	return result
}

fn (mut c Client) translate(text string, source_lang string, target_lang string) !string {
	src_cstr := if source_lang.len > 0 { &char(source_lang.str) } else { voidptr(0) }
	tgt_cstr := if target_lang.len > 0 { &char(target_lang.str) } else { voidptr(0) }
	mut response := &char(0)
	ret := C.misskey_translate(c.c_client, &char(text.str), src_cstr, tgt_cstr, &response)
	if ret != 0 {
		return error('translate failed')
	}
	result := unsafe { cstring_to_vstring(response) }
	C.misskey_free_string(c.c_client, response)
	return result
}

fn main() {
	host := os.args[1] or { 'localhost:3000' }
	token := os.args[2] or { 'test_token_12345' }
	
	println('===========================================')
	println('  Misskey V Client Test')
	println('===========================================')
	println('Host: ${host}')
	println('Token: ${token}')
	println('')
	
	mut client := new_client(host) or {
		println('Failed to create client: ${err}')
		return
	}
	defer {
		unsafe { client.free() }
	}
	
	client.set_token(token)
	client.set_debug(true)
	
	println('--- Testing APIs ---')
	
	println('')
	println('=== meta ===')
	result := client.meta() or {
		println('Error: ${err}')
		return
	}
	println(result)
	
	println('')
	println('=== notes_timeline ===')
	result = client.notes_timeline(3, true) or {
		println('Error: ${err}')
		return
	}
	println(result)
	
	println('')
	println('=== i_notifications ===')
	result = client.i_notifications(5) or {
		println('Error: ${err}')
		return
	}
	println(result)
	
	println('')
	println('=== drive ===')
	result = client.drive() or {
		println('Error: ${err}')
		return
	}
	println(result)
	
	println('')
	println('=== drive_files ===')
	result = client.drive_files(5, 0) or {
		println('Error: ${err}')
		return
	}
	println(result)
	
	println('')
	println('=== drive_files_show ===')
	result = client.drive_files_show('test_file_id_123', '') or {
		println('Error: ${err}')
		return
	}
	println(result)
	
	println('')
	println('=== drive_files_upload_from_url ===')
	result = client.drive_files_upload_from_url('https://example.com/test.png', '', false, '') or {
		println('Error: ${err}')
		return
	}
	println(result)
	
	println('')
	println('=== drive_folders ===')
	result = client.drive_folders(5, '') or {
		println('Error: ${err}')
		return
	}
	println(result)
	
	println('')
	println('=== translate ===')
	result = client.translate('Hello', 'en', 'ja') or {
		println('Error: ${err}')
		return
	}
	println(result)
	
	println('')
	println('===========================================')
	println('  Done')
	println('===========================================')
}
