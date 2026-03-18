module misskey

#flag linux -I./src
#flag linux -L.
#flag linux -lmisskey
#flag linux -lcurl

struct C.MisskeyClient {}

fn C.misskey_client_new(host &char) &C.MisskeyClient
fn C.misskey_client_free(client &C.MisskeyClient)
fn C.misskey_client_set_token(client &C.MisskeyClient, token &char)
fn C.misskey_client_set_timeout(client &C.MisskeyClient, timeout_secs int)
fn C.misskey_request(client &C.MisskeyClient, endpoint &char, body &char, response &&char) int
fn C.misskey_meta(client &C.MisskeyClient, response &&char) int
fn C.misskey_notes_timeline(client &C.MisskeyClient, limit int, local int, response &&char) int
fn C.misskey_notes_create(client &C.MisskeyClient, text &char, reply_id &char, renote_id &char, response &&char) int
fn C.misskey_i_notifications(client &C.MisskeyClient, limit int, response &&char) int
fn C.misskey_drive(client &C.MisskeyClient, response &&char) int
fn C.misskey_drive_files(client &C.MisskeyClient, limit int, folder_id int, response &&char) int
fn C.misskey_drive_files_create(client &C.MisskeyClient, file_path &char, folder_id &char, name &char, response &&char) int
fn C.misskey_drive_files_delete(client &C.MisskeyClient, file_id &char, response &&char) int
fn C.misskey_drive_files_update(client &C.MisskeyClient, file_id &char, folder_id &char, name &char, response &&char) int
fn C.misskey_drive_files_find(client &C.MisskeyClient, hash &char, response &&char) int
fn C.misskey_drive_files_show(client &C.MisskeyClient, file_id &char, url &char, response &&char) int
fn C.misskey_drive_files_upload_from_url(client &C.MisskeyClient, url &char, folder_id &char, is_sensitive int, comment &char, response &&char) int

type WriteCallback = fn (voidptr, int, int, voidptr) int

fn C.misskey_drive_files_download(client &C.MisskeyClient, file_id &char, options voidptr, http_code &int, content_length &int) int

fn C.misskey_drive_folders(client &C.MisskeyClient, limit int, folder_id &char, response &&char) int
fn C.misskey_drive_folders_create(client &C.MisskeyClient, name &char, parent_id &char, response &&char) int
fn C.misskey_drive_folders_delete(client &C.MisskeyClient, folder_id &char, response &&char) int
fn C.misskey_drive_folders_update(client &C.MisskeyClient, folder_id &char, name &char, parent_id &char, response &&char) int
fn C.misskey_translate(client &C.MisskeyClient, text &char, source_lang &char, target_lang &char, response &&char) int
fn C.misskey_request_set_debug(client &C.MisskeyClient, enable int)
fn C.misskey_free_string(client &C.MisskeyClient, str &char)
fn C.misskey_error_str(err int) &char

fn C.misskey_client_new_with_allocator(host &char, allocator voidptr) &C.MisskeyClient
fn C.misskey_client_get_allocator(client &C.MisskeyClient) voidptr
fn C.misskey_request_print_curl(client &C.MisskeyClient, endpoint &char, body &char)

// Error codes
pub enum MisskeyError {
	ok            = 0
	invalid_param = 1
	network       = 2
	http          = 3
	json          = 4
	auth          = 5
	alloc         = 6
	unknown       = 7
}

fn (e MisskeyError) str() string {
	return unsafe { cstring_to_vstring(C.misskey_error_str(int(e))) }
}

// Client wrapper
pub struct Client {
	c_client &C.MisskeyClient
}

pub fn new(host string) !Client {
	c_client := C.misskey_client_new(&char(host.str))
	if c_client == unsafe { nil } {
		return error('failed to create client')
	}
	return Client{c_client}
}

pub fn (mut c Client) free() {
	C.misskey_client_free(c.c_client)
}

pub fn (mut c Client) set_token(token string) {
	C.misskey_client_set_token(c.c_client, &char(token.str))
}

pub fn (mut c Client) set_timeout(sec int) {
	C.misskey_client_set_timeout(c.c_client, sec)
}

pub fn (mut c Client) set_debug(enable bool) {
	C.misskey_request_set_debug(c.c_client, if enable { 1 } else { 0 })
}

fn (c &Client) do_request(endpoint string, body string) !string {
	mut response := &char(0)
	ret := C.misskey_request(c.c_client, &char(endpoint.str), &char(body.str), &response)
	if ret != 0 {
		return error('request failed: ${MisskeyError(ret)}')
	}
	result := unsafe { cstring_to_vstring(response) }
	C.misskey_free_string(c.c_client, response)
	return result
}

pub fn (mut c Client) meta() !string {
	return c.do_request('meta', '{"detail":false}')
}

pub fn (mut c Client) notes_timeline(limit int, local bool) !string {
	local_val := if local { 1 } else { 0 }
	mut response := &char(0)
	ret := C.misskey_notes_timeline(c.c_client, limit, local_val, &response)
	if ret != 0 {
		return error('notes_timeline failed: ${MisskeyError(ret)}')
	}
	result := unsafe { cstring_to_vstring(response) }
	C.misskey_free_string(c.c_client, response)
	return result
}

pub fn (mut c Client) notes_create(text string, reply_id string, renote_id string) !string {
	reply_cstr := if reply_id.len > 0 { &char(reply_id.str) } else { voidptr(0) }
	renote_cstr := if renote_id.len > 0 { &char(renote_id.str) } else { voidptr(0) }
	mut response := &char(0)
	ret := C.misskey_notes_create(c.c_client, &char(text.str), reply_cstr, renote_cstr, &response)
	if ret != 0 {
		return error('notes_create failed: ${MisskeyError(ret)}')
	}
	result := unsafe { cstring_to_vstring(response) }
	C.misskey_free_string(c.c_client, response)
	return result
}

pub fn (mut c Client) i_notifications(limit int) !string {
	mut response := &char(0)
	ret := C.misskey_i_notifications(c.c_client, limit, &response)
	if ret != 0 {
		return error('i_notifications failed: ${MisskeyError(ret)}')
	}
	result := unsafe { cstring_to_vstring(response) }
	C.misskey_free_string(c.c_client, response)
	return result
}

pub fn (mut c Client) drive() !string {
	mut response := &char(0)
	ret := C.misskey_drive(c.c_client, &response)
	if ret != 0 {
		return error('drive failed: ${MisskeyError(ret)}')
	}
	result := unsafe { cstring_to_vstring(response) }
	C.misskey_free_string(c.c_client, response)
	return result
}

pub fn (mut c Client) drive_files(limit int, folder_id int) !string {
	mut response := &char(0)
	ret := C.misskey_drive_files(c.c_client, limit, folder_id, &response)
	if ret != 0 {
		return error('drive_files failed: ${MisskeyError(ret)}')
	}
	result := unsafe { cstring_to_vstring(response) }
	C.misskey_free_string(c.c_client, response)
	return result
}

pub fn (mut c Client) drive_files_create(file_path string, folder_id string, name string) !string {
	folder_cstr := if folder_id.len > 0 { &char(folder_id.str) } else { voidptr(0) }
	name_cstr := if name.len > 0 { &char(name.str) } else { voidptr(0) }
	mut response := &char(0)
	ret := C.misskey_drive_files_create(c.c_client, &char(file_path.str), folder_cstr, name_cstr, &response)
	if ret != 0 {
		return error('drive_files_create failed: ${MisskeyError(ret)}')
	}
	result := unsafe { cstring_to_vstring(response) }
	C.misskey_free_string(c.c_client, response)
	return result
}

pub fn (mut c Client) drive_files_delete(file_id string) !string {
	mut response := &char(0)
	ret := C.misskey_drive_files_delete(c.c_client, &char(file_id.str), &response)
	if ret != 0 {
		return error('drive_files_delete failed: ${MisskeyError(ret)}')
	}
	result := unsafe { cstring_to_vstring(response) }
	C.misskey_free_string(c.c_client, response)
	return result
}

pub fn (mut c Client) drive_files_update(file_id string, folder_id string, name string) !string {
	folder_cstr := if folder_id.len > 0 { &char(folder_id.str) } else { voidptr(0) }
	name_cstr := if name.len > 0 { &char(name.str) } else { voidptr(0) }
	mut response := &char(0)
	ret := C.misskey_drive_files_update(c.c_client, &char(file_id.str), folder_cstr, name_cstr, &response)
	if ret != 0 {
		return error('drive_files_update failed: ${MisskeyError(ret)}')
	}
	result := unsafe { cstring_to_vstring(response) }
	C.misskey_free_string(c.c_client, response)
	return result
}

pub fn (mut c Client) drive_files_find(hash string) !string {
	mut response := &char(0)
	ret := C.misskey_drive_files_find(c.c_client, &char(hash.str), &response)
	if ret != 0 {
		return error('drive_files_find failed: ${MisskeyError(ret)}')
	}
	result := unsafe { cstring_to_vstring(response) }
	C.misskey_free_string(c.c_client, response)
	return result
}

pub fn (mut c Client) drive_files_show(file_id string, url string) !string {
	file_id_cstr := if file_id.len > 0 { &char(file_id.str) } else { voidptr(0) }
	url_cstr := if url.len > 0 { &char(url.str) } else { voidptr(0) }
	mut response := &char(0)
	ret := C.misskey_drive_files_show(c.c_client, file_id_cstr, url_cstr, &response)
	if ret != 0 {
		return error('drive_files_show failed: ${MisskeyError(ret)}')
	}
	result := unsafe { cstring_to_vstring(response) }
	C.misskey_free_string(c.c_client, response)
	return result
}

pub fn (mut c Client) drive_files_upload_from_url(url string, folder_id string, is_sensitive bool, comment string) !string {
	folder_cstr := if folder_id.len > 0 { &char(folder_id.str) } else { voidptr(0) }
	comment_cstr := if comment.len > 0 { &char(comment.str) } else { voidptr(0) }
	sensitive_val := if is_sensitive { 1 } else { 0 }
	mut response := &char(0)
	ret := C.misskey_drive_files_upload_from_url(c.c_client, &char(url.str), folder_cstr, sensitive_val, comment_cstr, &response)
	if ret != 0 {
		return error('drive_files_upload_from_url failed: ${MisskeyError(ret)}')
	}
	result := unsafe { cstring_to_vstring(response) }
	C.misskey_free_string(c.c_client, response)
	return result
}

pub struct DownloadOptions {
	url             string
	file_id         string
	output_path     string
	resume_from     int
	follow_redirects bool
}

struct CDownloadOpts {
	url             &char
	output_path     &char
	write_cb        voidptr
	write_userdata  voidptr
	resume_from     int
	follow_redirects int
}

pub fn (mut c Client) drive_files_download(dl_opts DownloadOptions) !int {
	opts_c := &CDownloadOpts{
		url: if dl_opts.url.len > 0 { &char(dl_opts.url.str) } else { voidptr(0) }
		output_path: if dl_opts.output_path.len > 0 { &char(dl_opts.output_path.str) } else { voidptr(0) }
		write_cb: unsafe { nil }
		write_userdata: unsafe { nil }
		resume_from: dl_opts.resume_from
		follow_redirects: if dl_opts.follow_redirects { 1 } else { 0 }
	}
	file_id_cstr := if dl_opts.file_id.len > 0 { &char(dl_opts.file_id.str) } else { voidptr(0) }
	mut http_code := 0
	mut content_length := 0
	ret := C.misskey_drive_files_download(c.c_client, file_id_cstr, opts_c, &http_code, &content_length)
	if ret != 0 {
		return error('drive_files_download failed: ${MisskeyError(ret)}')
	}
	return http_code
}

pub fn (mut c Client) drive_folders(limit int, folder_id string) !string {
	folder_cstr := if folder_id.len > 0 { &char(folder_id.str) } else { voidptr(0) }
	mut response := &char(0)
	ret := C.misskey_drive_folders(c.c_client, limit, folder_cstr, &response)
	if ret != 0 {
		return error('drive_folders failed: ${MisskeyError(ret)}')
	}
	result := unsafe { cstring_to_vstring(response) }
	C.misskey_free_string(c.c_client, response)
	return result
}

pub fn (mut c Client) drive_folders_create(name string, parent_id string) !string {
	parent_cstr := if parent_id.len > 0 { &char(parent_id.str) } else { voidptr(0) }
	mut response := &char(0)
	ret := C.misskey_drive_folders_create(c.c_client, &char(name.str), parent_cstr, &response)
	if ret != 0 {
		return error('drive_folders_create failed: ${MisskeyError(ret)}')
	}
	result := unsafe { cstring_to_vstring(response) }
	C.misskey_free_string(c.c_client, response)
	return result
}

pub fn (mut c Client) drive_folders_delete(folder_id string) !string {
	mut response := &char(0)
	ret := C.misskey_drive_folders_delete(c.c_client, &char(folder_id.str), &response)
	if ret != 0 {
		return error('drive_folders_delete failed: ${MisskeyError(ret)}')
	}
	result := unsafe { cstring_to_vstring(response) }
	C.misskey_free_string(c.c_client, response)
	return result
}

pub fn (mut c Client) drive_folders_update(folder_id string, name string, parent_id string) !string {
	name_cstr := if name.len > 0 { &char(name.str) } else { voidptr(0) }
	parent_cstr := if parent_id.len > 0 { &char(parent_id.str) } else { voidptr(0) }
	mut response := &char(0)
	ret := C.misskey_drive_folders_update(c.c_client, &char(folder_id.str), name_cstr, parent_cstr, &response)
	if ret != 0 {
		return error('drive_folders_update failed: ${MisskeyError(ret)}')
	}
	result := unsafe { cstring_to_vstring(response) }
	C.misskey_free_string(c.c_client, response)
	return result
}

pub fn (mut c Client) translate(text string, source_lang string, target_lang string) !string {
	src_cstr := if source_lang.len > 0 { &char(source_lang.str) } else { voidptr(0) }
	tgt_cstr := if target_lang.len > 0 { &char(target_lang.str) } else { voidptr(0) }
	mut response := &char(0)
	ret := C.misskey_translate(c.c_client, &char(text.str), src_cstr, tgt_cstr, &response)
	if ret != 0 {
		return error('translate failed: ${MisskeyError(ret)}')
	}
	result := unsafe { cstring_to_vstring(response) }
	C.misskey_free_string(c.c_client, response)
	return result
}
