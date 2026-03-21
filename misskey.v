module misskey

import json // includes cJSON

#flag -I@DIR/src
#flag @DIR/src/misskey_client.o
#flag -lcurl

#include "misskey_client.h"

struct C.MisskeyClient {}

fn C.misskey_client_new(host charptr) &C.MisskeyClient
fn C.misskey_client_free(client &C.MisskeyClient)
fn C.misskey_client_set_token(client &C.MisskeyClient, token charptr)
fn C.misskey_client_set_timeout(client &C.MisskeyClient, timeout_secs int)
fn C.misskey_request(client &C.MisskeyClient, endpoint charptr, body charptr, response &charptr) int
fn C.misskey_meta_raw(client &C.MisskeyClient, response &charptr) int
fn C.misskey_users_show_raw(client &C.MisskeyClient, user_id charptr, username charptr, host charptr, detailed int, response &charptr) int
fn C.misskey_users_show(client &C.MisskeyClient, user_id charptr, username charptr, host charptr, detailed int, user_out &C.MisskeyUser) int
fn C.misskey_notes_timeline_raw(client &C.MisskeyClient, limit int, include_local_renotes int, response &charptr) int
fn C.misskey_notes_local_timeline_raw(client &C.MisskeyClient, limit int, response &charptr) int
fn C.misskey_notes_global_timeline_raw(client &C.MisskeyClient, limit int, response &charptr) int

struct C.MisskeyTimelineOptions {
mut:
	limit int
	with_files int
	with_renotes int
	with_replies int
	allow_partial int
	since_id charptr
	until_id charptr
	since_date int
	until_date int
}

fn C.misskey_notes_create_full_raw(client &C.MisskeyClient, text charptr, reply_id charptr, renote_id charptr, file_ids voidptr, file_ids_count int, visibility int, cw charptr, local_only int, channel_id charptr, auto_sensitive int, media_ids charptr, draft int, response &charptr) int
fn C.misskey_notes_create_full(client &C.MisskeyClient, text charptr, reply_id charptr, renote_id charptr, file_ids voidptr, file_ids_count int, visibility int, cw charptr, local_only int, channel_id charptr, auto_sensitive int, draft int, note_out &C.MisskeyNote) int

fn C.misskey_notes_local_timeline_full_raw(client &C.MisskeyClient, opts voidptr, response &charptr) int
fn C.misskey_notes_global_timeline_full_raw(client &C.MisskeyClient, opts voidptr, response &charptr) int

fn C.misskey_notes_create_raw(client &C.MisskeyClient, text charptr, reply_id charptr, renote_id charptr, response &charptr) int
fn C.misskey_i_notifications_raw(client &C.MisskeyClient, limit int, response &charptr) int
fn C.misskey_drive_raw(client &C.MisskeyClient, response &charptr) int
fn C.misskey_drive_files_raw(client &C.MisskeyClient, limit int, folder_id int, response &charptr) int
fn C.misskey_drive_files_create_raw(client &C.MisskeyClient, file_path charptr, folder_id charptr, name charptr, response &charptr) int
fn C.misskey_drive_files_delete_raw(client &C.MisskeyClient, file_id charptr, response &charptr) int
fn C.misskey_drive_files_update_raw(client &C.MisskeyClient, file_id charptr, folder_id charptr, name charptr, response &charptr) int
fn C.misskey_drive_files_find_raw(client &C.MisskeyClient, hash charptr, response &charptr) int
fn C.misskey_drive_files_show_raw(client &C.MisskeyClient, file_id charptr, url charptr, response &charptr) int
fn C.misskey_drive_files_upload_from_url_raw(client &C.MisskeyClient, url charptr, folder_id charptr, is_sensitive int, comment charptr, response &charptr) int

type WriteCallback = fn (voidptr, int, int, voidptr) int

fn C.misskey_drive_files_download(client &C.MisskeyClient, file_id charptr, options voidptr, http_code &int, content_length &int) int

fn C.misskey_drive_folders_raw(client &C.MisskeyClient, limit int, folder_id charptr, response &charptr) int
fn C.misskey_drive_folders_create_raw(client &C.MisskeyClient, name charptr, parent_id charptr, response &charptr) int
fn C.misskey_drive_folders_delete_raw(client &C.MisskeyClient, folder_id charptr, response &charptr) int
fn C.misskey_drive_folders_update_raw(client &C.MisskeyClient, folder_id charptr, name charptr, parent_id charptr, response &charptr) int
fn C.misskey_notes_raw(client &C.MisskeyClient, text charptr, reply_id charptr, renote_id charptr, channel_id charptr, limit int, offset int, user_id charptr, local_only int, reply int, renote int, with_files int, since_id charptr, until_id charptr, response &charptr) int
fn C.misskey_notes_show_raw(client &C.MisskeyClient, note_id charptr, response &charptr) int
fn C.misskey_notes_delete_raw(client &C.MisskeyClient, note_id charptr, response &charptr) int

fn C.misskey_clips_list_raw(client &C.MisskeyClient, response &charptr) int
fn C.misskey_clips_show_raw(client &C.MisskeyClient, clip_id charptr, response &charptr) int
fn C.misskey_clips_create_raw(client &C.MisskeyClient, name charptr, description charptr, is_public int, response &charptr) int
fn C.misskey_clips_update_raw(client &C.MisskeyClient, clip_id charptr, name charptr, description charptr, is_public int, response &charptr) int
fn C.misskey_clips_delete_raw(client &C.MisskeyClient, clip_id charptr, response &charptr) int
fn C.misskey_clips_add_note_raw(client &C.MisskeyClient, clip_id charptr, note_id charptr, response &charptr) int
fn C.misskey_clips_remove_note_raw(client &C.MisskeyClient, clip_id charptr, note_id charptr, response &charptr) int
fn C.misskey_clips_notes_raw(client &C.MisskeyClient, clip_id charptr, limit int, response &charptr) int

fn C.misskey_translate_raw(client &C.MisskeyClient, note_id charptr, target_lang charptr, response &charptr) int
fn C.misskey_request_set_debug(client &C.MisskeyClient, enable int)
fn C.misskey_free_string(client &C.MisskeyClient, str charptr)
fn C.misskey_error_str(err int) charptr
fn C.misskey_error_str_detail(client &C.MisskeyClient, err int) charptr

fn C.misskey_client_new_with_allocator(host charptr, allocator voidptr) &C.MisskeyClient
fn C.misskey_client_get_allocator(client &C.MisskeyClient) voidptr
fn C.misskey_request_print_curl(client &C.MisskeyClient, endpoint charptr, body charptr)
fn C.misskey_client_get_last_error(client &C.MisskeyClient, http_code &int, error_detail &charptr)

// C struct declarations for structured API
struct C.MisskeyUser {
mut:
	id [32]u8
	name [128]u8
	username [64]u8
	host [128]u8
	avatar_url [512]u8
	avatar_blurhash [64]u8
	banner_url [512]u8
	description [1024]u8
	url [512]u8
	followers_count int
	following_count int
	notes_count int
	is_bot int
	is_cat int
	is_locked int
	is_silenced int
	has_pending_follow_request int
}

struct C.MisskeyNote {
mut:
	id [32]u8
	created_at [32]u8
	text [4096]u8
	cw [512]u8
	app_id [32]u8
	user_id [32]u8
	reply_id [32]u8
	renote_id [32]u8
	channel_id [32]u8
	uri [256]u8
	url [512]u8
	visibility int
	local_only int
	reactions_count int
	replies_count int
	renote_count int
	reaction_emojis [512]u8
	renote_text [4096]u8
	is_renote int
	is_reply int
	has_files int
	files_count int
	file_ids [16][32]u8
	user C.MisskeyUser
}

struct C.MisskeyNotification {
mut:
	id [32]u8
	created_at [32]u8
	type [32]u8
	user_id [32]u8
	user_name [128]u8
	note_id [32]u8
	reaction [64]u8
	message [512]u8
	user C.MisskeyUser
}

struct C.MisskeyDriveFile {
mut:
	id [32]u8
	created_at [32]u8
	name [256]u8
	type [64]u8
	md5 [64]u8
	size usize
	url [512]u8
	thumbnail_url [512]u8
	folder_id [32]u8
	user_id [32]u8
	is_sensitive int
}

struct C.MisskeyDriveFolder {
mut:
	id [32]u8
	created_at [32]u8
	name [128]u8
	parent_id [32]u8
	folders_count int
	files_count int
}

struct C.MisskeyDriveInfo {
mut:
	capacity int
	usage int
	drive_usage_over_quota int
	inc_capacity int
}

struct C.MisskeyTranslateResult {
mut:
	text [4096]u8
	source_lang [16]byte
	target_lang [16]byte
}

struct C.MisskeyClip {
mut:
	id [32]u8
	created_at [32]u8
	name [128]u8
	description [512]u8
	is_public int
	notes_count int
}

struct C.MisskeyMeta {
mut:
	name [128]u8
	version [32]u8
	uri [256]u8
	description [1024]byte
	maintainer_name [128]u8
	max_note_text_length int
	enable_emoji_reactions int
	drive_capacity int
}

// Structured API C functions
fn C.misskey_note_init(note &C.MisskeyNote)
fn C.misskey_user_init(user &C.MisskeyUser)
fn C.misskey_notification_init(n &C.MisskeyNotification)
fn C.misskey_drive_file_init(f &C.MisskeyDriveFile)
fn C.misskey_drive_folder_init(f &C.MisskeyDriveFolder)
fn C.misskey_drive_info_init(info &C.MisskeyDriveInfo)
fn C.misskey_translate_result_init(r &C.MisskeyTranslateResult)
fn C.misskey_clip_init(c &C.MisskeyClip)
fn C.misskey_meta_init(m &C.MisskeyMeta)

fn C.misskey_meta(client &C.MisskeyClient, meta &C.MisskeyMeta) int
fn C.misskey_notes_timeline(client &C.MisskeyClient, limit int, include_local_renotes int, notes_out &&C.MisskeyNote, count_out &int) int
fn C.misskey_notes_local_timeline(client &C.MisskeyClient, limit int, notes_out &&C.MisskeyNote, count_out &int) int
fn C.misskey_notes_local_timeline_full(client &C.MisskeyClient, opts voidptr, notes_out &&C.MisskeyNote, count_out &int) int
fn C.misskey_notes_global_timeline(client &C.MisskeyClient, limit int, notes_out &&C.MisskeyNote, count_out &int) int
fn C.misskey_notes_global_timeline_full(client &C.MisskeyClient, opts voidptr, notes_out &&C.MisskeyNote, count_out &int) int
fn C.misskey_notes_create(client &C.MisskeyClient, text charptr, reply_id charptr, renote_id charptr, note_out &C.MisskeyNote) int
fn C.misskey_notes_show(client &C.MisskeyClient, note_id charptr, note_out &C.MisskeyNote) int
fn C.misskey_notes_delete(client &C.MisskeyClient, note_id charptr, note_id_out &byte) int
fn C.misskey_notes(client &C.MisskeyClient, text charptr, reply_id charptr, renote_id charptr, channel_id charptr, limit int, offset int, user_id charptr, local_only int, reply int, renote int, with_files int, since_id charptr, until_id charptr, notes_out &&C.MisskeyNote, count_out &int) int
fn C.misskey_i_notifications(client &C.MisskeyClient, limit int, notifications_out &&C.MisskeyNotification, count_out &int) int
fn C.misskey_drive(client &C.MisskeyClient, info &C.MisskeyDriveInfo) int
fn C.misskey_drive_files(client &C.MisskeyClient, limit int, folder_id charptr, files_out &&C.MisskeyDriveFile, count_out &int) int
fn C.misskey_drive_files_create(client &C.MisskeyClient, file_path charptr, folder_id charptr, name charptr, file_out &C.MisskeyDriveFile) int
fn C.misskey_drive_files_delete(client &C.MisskeyClient, file_id charptr, file_id_out &byte) int
fn C.misskey_drive_files_update(client &C.MisskeyClient, file_id charptr, folder_id charptr, name charptr, file_out &C.MisskeyDriveFile) int
fn C.misskey_drive_files_find(client &C.MisskeyClient, hash charptr, files_out &&C.MisskeyDriveFile, count_out &int) int
fn C.misskey_drive_files_show(client &C.MisskeyClient, file_id charptr, url charptr, file_out &C.MisskeyDriveFile) int
fn C.misskey_drive_files_upload_from_url(client &C.MisskeyClient, url charptr, folder_id charptr, is_sensitive int, comment charptr, file_out &C.MisskeyDriveFile) int
fn C.misskey_drive_folders(client &C.MisskeyClient, limit int, folder_id charptr, folders_out &&C.MisskeyDriveFolder, count_out &int) int
fn C.misskey_drive_folders_create(client &C.MisskeyClient, name charptr, parent_id charptr, folder_out &C.MisskeyDriveFolder) int
fn C.misskey_drive_folders_delete(client &C.MisskeyClient, folder_id charptr, folder_id_out &byte) int
fn C.misskey_drive_folders_update(client &C.MisskeyClient, folder_id charptr, name charptr, parent_id charptr, folder_out &C.MisskeyDriveFolder) int
fn C.misskey_translate(client &C.MisskeyClient, note_id charptr, target_lang charptr, result_out &C.MisskeyTranslateResult) int
fn C.misskey_clips_list(client &C.MisskeyClient, clips_out &&C.MisskeyClip, count_out &int) int
fn C.misskey_clips_show(client &C.MisskeyClient, clip_id charptr, clip_out &C.MisskeyClip) int
fn C.misskey_clips_create(client &C.MisskeyClient, name charptr, description charptr, is_public int, clip_out &C.MisskeyClip) int
fn C.misskey_clips_update(client &C.MisskeyClient, clip_id charptr, name charptr, description charptr, is_public int, clip_out &C.MisskeyClip) int
fn C.misskey_clips_delete(client &C.MisskeyClient, clip_id charptr, clip_id_out &byte) int
fn C.misskey_clips_notes(client &C.MisskeyClient, clip_id charptr, limit int, notes_out &&C.MisskeyNote, count_out &int) int

fn C.misskey_free_notes(client &C.MisskeyClient, notes &C.MisskeyNote, count int)
fn C.misskey_free_notifications(client &C.MisskeyClient, notifications &C.MisskeyNotification, count int)
fn C.misskey_free_drive_files(client &C.MisskeyClient, files &C.MisskeyDriveFile, count int)
fn C.misskey_free_drive_folders(client &C.MisskeyClient, folders &C.MisskeyDriveFolder, count int)
fn C.misskey_free_clips(client &C.MisskeyClient, clips &C.MisskeyClip, count int)

pub enum StreamChannel {
	main           = 0
	home_timeline  = 1
	local_timeline = 2
	hybrid_timeline = 3
	global_timeline = 4
}

struct C.MisskeyStream {}

type StreamCallback = fn (msg_type string, body string, user_data voidptr)

fn C.misskey_stream_new(host charptr, token charptr) &C.MisskeyStream
fn C.misskey_stream_free(stream &C.MisskeyStream)
fn C.misskey_stream_connect(stream &C.MisskeyStream, channel int, channel_id charptr) int
fn C.misskey_stream_disconnect(stream &C.MisskeyStream, channel_id charptr) int
fn C.misskey_stream_poll(stream &C.MisskeyStream, timeout_ms int) int
fn C.misskey_stream_send(stream &C.MisskeyStream, channel_id charptr, msg_type charptr, body charptr) int
fn C.misskey_stream_set_callback(stream &C.MisskeyStream, callback StreamCallback, user_data voidptr)
fn C.misskey_stream_subscribe_note(stream &C.MisskeyStream, note_id charptr) int
fn C.misskey_stream_unsubscribe_note(stream &C.MisskeyStream, note_id charptr) int

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

fn (e MisskeyError) detailed(c &Client) string {
	return unsafe { cstring_to_vstring(C.misskey_error_str_detail(c.c_client, int(e))) }
}

// Client wrapper
pub struct Client {
	c_client &C.MisskeyClient
mut:
	host string
}

pub fn new(host string) !Client {
	c_client := C.misskey_client_new(&char(host.str))
	if c_client == unsafe { nil } {
		return error('failed to create client')
	}
	return Client{
		c_client: c_client
		host: host
	}
}

pub fn (c &Client) free_raw() {
	C.misskey_client_free(c.c_client)
}

pub fn (c &Client) set_token(token string) {
	C.misskey_client_set_token(c.c_client, &char(token.str))
}

pub fn (c &Client) host() string {
	return c.host
}

pub fn (c &Client) set_timeout(sec int) {
	C.misskey_client_set_timeout(c.c_client, sec)
}

pub fn (c &Client) set_debug(enable bool) {
	C.misskey_request_set_debug(c.c_client, if enable { 1 } else { 0 })
}

pub fn (c &Client) get_last_error() (int, string) {
	mut http_code := 0
	mut error_detail := &char(0)
	C.misskey_client_get_last_error(c.c_client, &http_code, &error_detail)
	detail := if !isnil(error_detail) {
		unsafe { cstring_to_vstring(error_detail) }
	} else {
		''
	}
	return http_code, detail
}

fn (c &Client) get_error_msg() string {
	http_code, detail := c.get_last_error()
	if http_code > 0 {
		if detail.len > 0 {
			return 'HTTP ${http_code}: ${detail}'
		}
		return 'HTTP ${http_code}'
	}
	if detail.len > 0 {
		return detail
	}
	return ''
}

fn (c &Client) do_request(endpoint string, body string) !string {
	mut response := &char(0)
	ret := C.misskey_request(c.c_client, &char(endpoint.str), &char(body.str), &response)
	if ret != 0 {
		return error('${MisskeyError(ret).detailed(c)}')
	}
	result := unsafe { cstring_to_vstring(response) }
	C.misskey_free_string(c.c_client, response)
	return result
}

pub fn (c &Client) meta_raw() !string {
	return c.do_request('meta', '{"detail":false}')
}

pub fn (c &Client) users_show_raw(user_id string, username string, host string, detailed bool) !string {
	user_id_cstr := if user_id.len > 0 { &char(user_id.str) } else { voidptr(0) }
	username_cstr := if username.len > 0 { &char(username.str) } else { voidptr(0) }
	host_cstr := if host.len > 0 { &char(host.str) } else { voidptr(0) }
	mut response := &char(0)
	ret := C.misskey_users_show_raw(c.c_client, user_id_cstr, username_cstr, host_cstr, if detailed { 1 } else { 0 }, &response)
	if ret != 0 {
		return error('users_show failed: ${MisskeyError(ret).detailed(c)}')
	}
	result := unsafe { cstring_to_vstring(response) }
	C.misskey_free_string(c.c_client, response)
	return result
}

pub fn (c &Client) notes_timeline_raw(limit int, include_local_renotes bool) !string {
	local_val := if include_local_renotes { 1 } else { 0 }
	mut response := &char(0)
	ret := C.misskey_notes_timeline_raw(c.c_client, limit, local_val, &response)
	if ret != 0 {
		return error('notes_timeline failed: ${MisskeyError(ret).detailed(c)}')
	}
	result := unsafe { cstring_to_vstring(response) }
	C.misskey_free_string(c.c_client, response)
	return result
}

pub fn (c &Client) notes_local_timeline_raw(limit int) !string {
	mut response := &char(0)
	ret := C.misskey_notes_local_timeline_raw(c.c_client, limit, &response)
	if ret != 0 {
		return error('notes_local_timeline failed: ${MisskeyError(ret).detailed(c)}')
	}
	result := unsafe { cstring_to_vstring(response) }
	C.misskey_free_string(c.c_client, response)
	return result
}

pub fn (c &Client) notes_global_timeline_raw(limit int) !string {
	mut response := &char(0)
	ret := C.misskey_notes_global_timeline_raw(c.c_client, limit, &response)
	if ret != 0 {
		return error('notes_global_timeline failed: ${MisskeyError(ret).detailed(c)}')
	}
	result := unsafe { cstring_to_vstring(response) }
	C.misskey_free_string(c.c_client, response)
	return result
}

pub fn (c &Client) notes_create_raw(text string, reply_id string, renote_id string) !string {
	reply_cstr := if reply_id.len > 0 { &char(reply_id.str) } else { voidptr(0) }
	renote_cstr := if renote_id.len > 0 { &char(renote_id.str) } else { voidptr(0) }
	mut response := &char(0)
	ret := C.misskey_notes_create_raw(c.c_client, &char(text.str), reply_cstr, renote_cstr, &response)
	if ret != 0 {
		return error('notes_create failed: ${MisskeyError(ret).detailed(c)}')
	}
	result := unsafe { cstring_to_vstring(response) }
	C.misskey_free_string(c.c_client, response)
	return result
}

pub struct CreateNoteOptions {
pub:
	text         string
	reply_id     string
	renote_id    string
	file_ids     []string
	visibility   int
	cw           string
	local_only   bool
	channel_id   string
	auto_sensitive bool
	draft        bool
}

pub fn (c &Client) notes_create_full_raw(opts CreateNoteOptions) !string {
	reply_cstr := if opts.reply_id.len > 0 { &char(opts.reply_id.str) } else { voidptr(0) }
	renote_cstr := if opts.renote_id.len > 0 { &char(opts.renote_id.str) } else { voidptr(0) }
	cw_cstr := if opts.cw.len > 0 { &char(opts.cw.str) } else { voidptr(0) }
	channel_cstr := if opts.channel_id.len > 0 { &char(opts.channel_id.str) } else { voidptr(0) }
	
	mut file_ids_ptr := &char(unsafe { nil })
	if opts.file_ids.len > 0 {
		file_ids_ptr = &char(opts.file_ids[0].str)
	}
	
	mut response := &char(0)
	ret := C.misskey_notes_create_full_raw(
		c.c_client,
		&char(opts.text.str),
		reply_cstr,
		renote_cstr,
		file_ids_ptr,
		opts.file_ids.len,
		opts.visibility,
		cw_cstr,
		if opts.local_only { 1 } else { 0 },
		channel_cstr,
		if opts.auto_sensitive { 1 } else { 0 },
		voidptr(0),
		if opts.draft { 1 } else { 0 },
		&response
	)
	if ret != 0 {
		return error('notes_create_full failed: ${MisskeyError(ret).detailed(c)}')
	}
	result := unsafe { cstring_to_vstring(response) }
	C.misskey_free_string(c.c_client, response)
	return result
}

pub fn (c &Client) i_notifications_raw(limit int) !string {
	mut response := &char(0)
	ret := C.misskey_i_notifications_raw(c.c_client, limit, &response)
	if ret != 0 {
		return error('i_notifications failed: ${MisskeyError(ret).detailed(c)}')
	}
	result := unsafe { cstring_to_vstring(response) }
	C.misskey_free_string(c.c_client, response)
	return result
}

pub fn (c &Client) drive_raw() !string {
	mut response := &char(0)
	ret := C.misskey_drive_raw(c.c_client, &response)
	if ret != 0 {
		return error('drive failed: ${MisskeyError(ret).detailed(c)}')
	}
	result := unsafe { cstring_to_vstring(response) }
	C.misskey_free_string(c.c_client, response)
	return result
}

pub fn (c &Client) drive_files_raw(limit int, folder_id int) !string {
	mut response := &char(0)
	ret := C.misskey_drive_files_raw(c.c_client, limit, folder_id, &response)
	if ret != 0 {
		return error('drive_files failed: ${MisskeyError(ret).detailed(c)}')
	}
	result := unsafe { cstring_to_vstring(response) }
	C.misskey_free_string(c.c_client, response)
	return result
}

pub fn (c &Client) drive_files_create_raw(file_path string, folder_id string, name string) !string {
	folder_cstr := if folder_id.len > 0 { &char(folder_id.str) } else { voidptr(0) }
	name_cstr := if name.len > 0 { &char(name.str) } else { voidptr(0) }
	mut response := &char(0)
	ret := C.misskey_drive_files_create_raw(c.c_client, &char(file_path.str), folder_cstr, name_cstr, &response)
	if ret != 0 {
		return error('drive_files_create failed: ${MisskeyError(ret).detailed(c)}')
	}
	result := unsafe { cstring_to_vstring(response) }
	C.misskey_free_string(c.c_client, response)
	return result
}

pub fn (c &Client) drive_files_delete_raw(file_id string) !string {
	mut response := &char(0)
	ret := C.misskey_drive_files_delete_raw(c.c_client, &char(file_id.str), &response)
	if ret != 0 {
		return error('drive_files_delete failed: ${MisskeyError(ret).detailed(c)}')
	}
	result := unsafe { cstring_to_vstring(response) }
	C.misskey_free_string(c.c_client, response)
	return result
}

pub fn (c &Client) drive_files_update_raw(file_id string, folder_id string, name string) !string {
	folder_cstr := if folder_id.len > 0 { &char(folder_id.str) } else { voidptr(0) }
	name_cstr := if name.len > 0 { &char(name.str) } else { voidptr(0) }
	mut response := &char(0)
	ret := C.misskey_drive_files_update_raw(c.c_client, &char(file_id.str), folder_cstr, name_cstr, &response)
	if ret != 0 {
		return error('drive_files_update failed: ${MisskeyError(ret).detailed(c)}')
	}
	result := unsafe { cstring_to_vstring(response) }
	C.misskey_free_string(c.c_client, response)
	return result
}

pub fn (c &Client) drive_files_find_raw(hash string) !string {
	mut response := &char(0)
	ret := C.misskey_drive_files_find_raw(c.c_client, &char(hash.str), &response)
	if ret != 0 {
		return error('drive_files_find failed: ${MisskeyError(ret).detailed(c)}')
	}
	result := unsafe { cstring_to_vstring(response) }
	C.misskey_free_string(c.c_client, response)
	return result
}

pub fn (c &Client) drive_files_show_raw(file_id string, url string) !string {
	file_id_cstr := if file_id.len > 0 { &char(file_id.str) } else { voidptr(0) }
	url_cstr := if url.len > 0 { &char(url.str) } else { voidptr(0) }
	mut response := &char(0)
	ret := C.misskey_drive_files_show_raw(c.c_client, file_id_cstr, url_cstr, &response)
	if ret != 0 {
		return error('drive_files_show failed: ${MisskeyError(ret).detailed(c)}')
	}
	result := unsafe { cstring_to_vstring(response) }
	C.misskey_free_string(c.c_client, response)
	return result
}

pub fn (c &Client) drive_files_upload_from_url_raw(url string, folder_id string, is_sensitive bool, comment string) !string {
	folder_cstr := if folder_id.len > 0 { &char(folder_id.str) } else { voidptr(0) }
	comment_cstr := if comment.len > 0 { &char(comment.str) } else { voidptr(0) }
	sensitive_val := if is_sensitive { 1 } else { 0 }
	mut response := &char(0)
	ret := C.misskey_drive_files_upload_from_url_raw(c.c_client, &char(url.str), folder_cstr, sensitive_val, comment_cstr, &response)
	if ret != 0 {
		return error('drive_files_upload_from_url failed: ${MisskeyError(ret).detailed(c)}')
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
	url             charptr
	output_path     charptr
	write_cb        voidptr
	write_userdata  voidptr
	resume_from     int
	follow_redirects int
}

pub fn (c &Client) drive_files_download(dl_opts DownloadOptions) !int {
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
		return error('drive_files_download failed: ${MisskeyError(ret).detailed(c)}')
	}
	return http_code
}

pub fn (c &Client) drive_folders_raw(limit int, folder_id string) !string {
	folder_cstr := if folder_id.len > 0 { &char(folder_id.str) } else { voidptr(0) }
	mut response := &char(0)
	ret := C.misskey_drive_folders_raw(c.c_client, limit, folder_cstr, &response)
	if ret != 0 {
		return error('drive_folders failed: ${MisskeyError(ret).detailed(c)}')
	}
	result := unsafe { cstring_to_vstring(response) }
	C.misskey_free_string(c.c_client, response)
	return result
}

pub fn (c &Client) drive_folders_create_raw(name string, parent_id string) !string {
	parent_cstr := if parent_id.len > 0 { &char(parent_id.str) } else { voidptr(0) }
	mut response := &char(0)
	ret := C.misskey_drive_folders_create_raw(c.c_client, &char(name.str), parent_cstr, &response)
	if ret != 0 {
		return error('drive_folders_create failed: ${MisskeyError(ret).detailed(c)}')
	}
	result := unsafe { cstring_to_vstring(response) }
	C.misskey_free_string(c.c_client, response)
	return result
}

pub fn (c &Client) drive_folders_delete_raw(folder_id string) !string {
	mut response := &char(0)
	ret := C.misskey_drive_folders_delete_raw(c.c_client, &char(folder_id.str), &response)
	if ret != 0 {
		return error('drive_folders_delete failed: ${MisskeyError(ret).detailed(c)}')
	}
	result := unsafe { cstring_to_vstring(response) }
	C.misskey_free_string(c.c_client, response)
	return result
}

pub fn (c &Client) drive_folders_update_raw(folder_id string, name string, parent_id string) !string {
	name_cstr := if name.len > 0 { &char(name.str) } else { voidptr(0) }
	parent_cstr := if parent_id.len > 0 { &char(parent_id.str) } else { voidptr(0) }
	mut response := &char(0)
	ret := C.misskey_drive_folders_update_raw(c.c_client, &char(folder_id.str), name_cstr, parent_cstr, &response)
	if ret != 0 {
		return error('drive_folders_update failed: ${MisskeyError(ret).detailed(c)}')
	}
	result := unsafe { cstring_to_vstring(response) }
	C.misskey_free_string(c.c_client, response)
	return result
}

pub fn (c &Client) translate_raw(note_id string, target_lang string) !string {
	tgt_cstr := if target_lang.len > 0 { &char(target_lang.str) } else { voidptr(0) }
	mut response := &char(0)
	ret := C.misskey_translate_raw(c.c_client, &char(note_id.str), tgt_cstr, &response)
	if ret != 0 {
		return error('translate failed: ${MisskeyError(ret).detailed(c)}')
	}
	result := unsafe { cstring_to_vstring(response) }
	C.misskey_free_string(c.c_client, response)
	return result
}

pub fn (c &Client) notes_raw(text string, reply_id string, renote_id string, channel_id string, limit int, offset int, user_id string, local_only bool, reply bool, renote bool, with_files bool, since_id string, until_id string) !string {
	text_cstr := if text.len > 0 { &char(text.str) } else { voidptr(0) }
	reply_cstr := if reply_id.len > 0 { &char(reply_id.str) } else { voidptr(0) }
	renote_cstr := if renote_id.len > 0 { &char(renote_id.str) } else { voidptr(0) }
	channel_cstr := if channel_id.len > 0 { &char(channel_id.str) } else { voidptr(0) }
	user_cstr := if user_id.len > 0 { &char(user_id.str) } else { voidptr(0) }
	since_cstr := if since_id.len > 0 { &char(since_id.str) } else { voidptr(0) }
	until_cstr := if until_id.len > 0 { &char(until_id.str) } else { voidptr(0) }
	mut response := &char(0)
	ret := C.misskey_notes_raw(c.c_client, text_cstr, reply_cstr, renote_cstr, channel_cstr, limit, offset, user_cstr, if local_only { 1 } else { 0 }, if reply { 1 } else { 0 }, if renote { 1 } else { 0 }, if with_files { 1 } else { 0 }, since_cstr, until_cstr, &response)
	if ret != 0 {
		return error('notes failed: ${MisskeyError(ret).detailed(c)}')
	}
	result := unsafe { cstring_to_vstring(response) }
	C.misskey_free_string(c.c_client, response)
	return result
}

pub fn (c &Client) notes_show_raw(note_id string) !string {
	mut response := &char(0)
	ret := C.misskey_notes_show_raw(c.c_client, &char(note_id.str), &response)
	if ret != 0 {
		return error('notes_show failed: ${MisskeyError(ret).detailed(c)}')
	}
	result := unsafe { cstring_to_vstring(response) }
	C.misskey_free_string(c.c_client, response)
	return result
}

pub fn (c &Client) notes_delete_raw(note_id string) !string {
	mut response := &char(0)
	ret := C.misskey_notes_delete_raw(c.c_client, &char(note_id.str), &response)
	if ret != 0 {
		return error('notes_delete failed: ${MisskeyError(ret).detailed(c)}')
	}
	result := unsafe { cstring_to_vstring(response) }
	C.misskey_free_string(c.c_client, response)
	return result
}

pub fn (c &Client) clips_list_raw() !string {
	mut response := &char(0)
	ret := C.misskey_clips_list_raw(c.c_client, &response)
	if ret != 0 {
		return error('clips_list failed: ${MisskeyError(ret).detailed(c)}')
	}
	result := unsafe { cstring_to_vstring(response) }
	C.misskey_free_string(c.c_client, response)
	return result
}

pub fn (c &Client) clips_show_raw(clip_id string) !string {
	mut response := &char(0)
	ret := C.misskey_clips_show_raw(c.c_client, &char(clip_id.str), &response)
	if ret != 0 {
		return error('clips_show failed: ${MisskeyError(ret).detailed(c)}')
	}
	result := unsafe { cstring_to_vstring(response) }
	C.misskey_free_string(c.c_client, response)
	return result
}

pub fn (c &Client) clips_create_raw(name string, description string, is_public bool) !string {
	desc_cstr := if description.len > 0 { &char(description.str) } else { voidptr(0) }
	mut response := &char(0)
	ret := C.misskey_clips_create_raw(c.c_client, &char(name.str), desc_cstr, if is_public { 1 } else { 0 }, &response)
	if ret != 0 {
		return error('clips_create failed: ${MisskeyError(ret).detailed(c)}')
	}
	result := unsafe { cstring_to_vstring(response) }
	C.misskey_free_string(c.c_client, response)
	return result
}

pub fn (c &Client) clips_update_raw(clip_id string, name string, description string, is_public bool) !string {
	name_cstr := if name.len > 0 { &char(name.str) } else { voidptr(0) }
	desc_cstr := if description.len > 0 { &char(description.str) } else { voidptr(0) }
	mut response := &char(0)
	ret := C.misskey_clips_update_raw(c.c_client, &char(clip_id.str), name_cstr, desc_cstr, if is_public { 1 } else { 0 }, &response)
	if ret != 0 {
		return error('clips_update failed: ${MisskeyError(ret).detailed(c)}')
	}
	result := unsafe { cstring_to_vstring(response) }
	C.misskey_free_string(c.c_client, response)
	return result
}

pub fn (c &Client) clips_delete_raw(clip_id string) !string {
	mut response := &char(0)
	ret := C.misskey_clips_delete_raw(c.c_client, &char(clip_id.str), &response)
	if ret != 0 {
		return error('clips_delete failed: ${MisskeyError(ret).detailed(c)}')
	}
	result := unsafe { cstring_to_vstring(response) }
	C.misskey_free_string(c.c_client, response)
	return result
}

pub fn (c &Client) clips_add_note_raw(clip_id string, note_id string) !string {
	mut response := &char(0)
	ret := C.misskey_clips_add_note_raw(c.c_client, &char(clip_id.str), &char(note_id.str), &response)
	if ret != 0 {
		return error('clips_add_note failed: ${MisskeyError(ret).detailed(c)}')
	}
	result := unsafe { cstring_to_vstring(response) }
	C.misskey_free_string(c.c_client, response)
	return result
}

pub fn (c &Client) clips_remove_note_raw(clip_id string, note_id string) !string {
	mut response := &char(0)
	ret := C.misskey_clips_remove_note_raw(c.c_client, &char(clip_id.str), &char(note_id.str), &response)
	if ret != 0 {
		return error('clips_remove_note failed: ${MisskeyError(ret).detailed(c)}')
	}
	result := unsafe { cstring_to_vstring(response) }
	C.misskey_free_string(c.c_client, response)
	return result
}

pub fn (c &Client) clips_notes_raw(clip_id string, limit int) !string {
	mut response := &char(0)
	ret := C.misskey_clips_notes_raw(c.c_client, &char(clip_id.str), limit, &response)
	if ret != 0 {
		return error('clips_notes failed: ${MisskeyError(ret).detailed(c)}')
	}
	result := unsafe { cstring_to_vstring(response) }
	C.misskey_free_string(c.c_client, response)
	return result
}

// V structs for structured API
@[heap]
pub struct User {
pub:
	id string
	name string
	username string
	host string
	avatar_url string
	avatar_blurhash string
	banner_url string
	description string
	url string
	followers_count int
	following_count int
	notes_count int
	is_bot bool
	is_cat bool
	is_locked bool
	is_silenced bool
	has_pending_follow_request bool
}

pub fn (u &User) full_username() string {
	if u.host.len > 0 {
		return '@${u.username}@${u.host}'
	}
	return '@${u.username}'
}

@[heap]
pub struct Note {
pub:
	id string
	created_at string
	text string
	cw string
	user_id string
	reply_id string
	renote_id string
	channel_id string
	local_only bool
	reactions_count int
	replies_count int
	renote_count int
	renote_text string
	is_renote bool
	is_reply bool
	has_files bool
	files_count int
	user User
}

@[heap]
pub struct Notification {
pub:
	id string
	created_at string
	type_ string
	user_id string
	user_name string
	note_id string
	reaction string
	message string
	user User
}

@[heap]
pub struct DriveFile {
pub:
	id string
	created_at string
	name string
	type_ string
	md5 string
	size usize
	url string
	thumbnail_url string
	folder_id string
	is_sensitive bool
}

@[heap]
pub struct DriveFolder {
pub:
	id string
	created_at string
	name string
	parent_id string
	folders_count int
	files_count int
}

@[heap]
pub struct DriveInfo {
pub:
	capacity int
	usage int
	is_over_quota bool
}

@[heap]
pub struct TranslateResult {
pub:
	text string
	source_lang string
	target_lang string
}

pub struct TimelineOptions {
pub:
	limit           int
	with_files      bool
	with_renotes    bool
	with_replies   bool
	allow_partial   bool
	since_id        string
	until_id        string
	since_date      int
	until_date      int
}

@[heap]
pub struct Clip {
pub:
	id string
	created_at string
	name string
	description string
	is_public bool
	notes_count int
}

@[heap]
pub struct Meta {
pub:
	name string
	version string
	uri string
	description string
	maintainer_name string
	max_note_text_length int
	enable_emoji_reactions bool
	drive_capacity int
}

// Helper to convert C.MisskeyUser to User
fn to_user(cuser &C.MisskeyUser) User {
	return User{
		id: unsafe { cstring_to_vstring(&char(cuser.id)) }
		name: unsafe { cstring_to_vstring(&char(cuser.name)) }
		username: unsafe { cstring_to_vstring(&char(cuser.username)) }
		host: unsafe { cstring_to_vstring(&char(cuser.host)) }
		avatar_url: unsafe { cstring_to_vstring(&char(cuser.avatar_url)) }
		avatar_blurhash: unsafe { cstring_to_vstring(&char(cuser.avatar_blurhash)) }
		banner_url: unsafe { cstring_to_vstring(&char(cuser.banner_url)) }
		description: unsafe { cstring_to_vstring(&char(cuser.description)) }
		url: unsafe { cstring_to_vstring(&char(cuser.url)) }
		followers_count: cuser.followers_count
		following_count: cuser.following_count
		notes_count: cuser.notes_count
		is_bot: cuser.is_bot != 0
		is_cat: cuser.is_cat != 0
		is_locked: cuser.is_locked != 0
		is_silenced: cuser.is_silenced != 0
		has_pending_follow_request: cuser.has_pending_follow_request != 0
	}
}

fn to_note(cnote &C.MisskeyNote) Note {
	return Note{
		id: unsafe { cstring_to_vstring(&char(cnote.id)) }
		created_at: unsafe { cstring_to_vstring(&char(cnote.created_at)) }
		text: unsafe { cstring_to_vstring(&char(cnote.text)) }
		cw: unsafe { cstring_to_vstring(&char(cnote.cw)) }
		user_id: unsafe { cstring_to_vstring(&char(cnote.user_id)) }
		reply_id: unsafe { cstring_to_vstring(&char(cnote.reply_id)) }
		renote_id: unsafe { cstring_to_vstring(&char(cnote.renote_id)) }
		channel_id: unsafe { cstring_to_vstring(&char(cnote.channel_id)) }
		local_only: cnote.local_only != 0
		reactions_count: cnote.reactions_count
		replies_count: cnote.replies_count
		renote_count: cnote.renote_count
		renote_text: unsafe { cstring_to_vstring(&char(cnote.renote_text)) }
		is_renote: cnote.is_renote != 0
		is_reply: cnote.is_reply != 0
		has_files: cnote.has_files != 0
		files_count: cnote.files_count
		user: to_user(&cnote.user)
	}
}

fn to_notification(cnotif &C.MisskeyNotification) Notification {
	return Notification{
		id: unsafe { cstring_to_vstring(&char(cnotif.id)) }
		created_at: unsafe { cstring_to_vstring(&char(cnotif.created_at)) }
		type_: unsafe { cstring_to_vstring(&char(cnotif.type)) }
		user_id: unsafe { cstring_to_vstring(&char(cnotif.user_id)) }
		user_name: unsafe { cstring_to_vstring(&char(cnotif.user_name)) }
		note_id: unsafe { cstring_to_vstring(&char(cnotif.note_id)) }
		reaction: unsafe { cstring_to_vstring(&char(cnotif.reaction)) }
		message: unsafe { cstring_to_vstring(&char(cnotif.message)) }
		user: to_user(&cnotif.user)
	}
}

fn to_drive_file(cfile &C.MisskeyDriveFile) DriveFile {
	return DriveFile{
		id: unsafe { cstring_to_vstring(&char(cfile.id)) }
		created_at: unsafe { cstring_to_vstring(&char(cfile.created_at)) }
		name: unsafe { cstring_to_vstring(&char(cfile.name)) }
		type_: unsafe { cstring_to_vstring(&char(cfile.type)) }
		md5: unsafe { cstring_to_vstring(&char(cfile.md5)) }
		size: cfile.size
		url: unsafe { cstring_to_vstring(&char(cfile.url)) }
		thumbnail_url: unsafe { cstring_to_vstring(&char(cfile.thumbnail_url)) }
		folder_id: unsafe { cstring_to_vstring(&char(cfile.folder_id)) }
		is_sensitive: cfile.is_sensitive != 0
	}
}

fn to_drive_folder(cfolder &C.MisskeyDriveFolder) DriveFolder {
	return DriveFolder{
		id: unsafe { cstring_to_vstring(&char(cfolder.id)) }
		created_at: unsafe { cstring_to_vstring(&char(cfolder.created_at)) }
		name: unsafe { cstring_to_vstring(&char(cfolder.name)) }
		parent_id: unsafe { cstring_to_vstring(&char(cfolder.parent_id)) }
		folders_count: cfolder.folders_count
		files_count: cfolder.files_count
	}
}

fn to_clip(clip &C.MisskeyClip) Clip {
	return Clip{
		id: unsafe { cstring_to_vstring(&char(clip.id)) }
		created_at: unsafe { cstring_to_vstring(&char(clip.created_at)) }
		name: unsafe { cstring_to_vstring(&char(clip.name)) }
		description: unsafe { cstring_to_vstring(&char(clip.description)) }
		is_public: clip.is_public != 0
		notes_count: clip.notes_count
	}
}

fn to_meta(cmeta &C.MisskeyMeta) Meta {
	return Meta{
		name: unsafe { cstring_to_vstring(&char(cmeta.name)) }
		version: unsafe { cstring_to_vstring(&char(cmeta.version)) }
		uri: unsafe { cstring_to_vstring(&char(cmeta.uri)) }
		description: unsafe { cstring_to_vstring(&char(cmeta.description)) }
		maintainer_name: unsafe { cstring_to_vstring(&char(cmeta.maintainer_name)) }
		max_note_text_length: cmeta.max_note_text_length
		enable_emoji_reactions: cmeta.enable_emoji_reactions != 0
		drive_capacity: cmeta.drive_capacity
	}
}

// Structured API methods
pub fn (c &Client) meta() !Meta {
	C.misskey_meta_init(voidptr(0))
	mut cmeta := &C.MisskeyMeta{}
	C.misskey_meta_init(cmeta)
	ret := C.misskey_meta(c.c_client, cmeta)
	if ret != 0 {
		return error('meta failed: ${MisskeyError(ret).detailed(c)}')
	}
	result := to_meta(cmeta)
	return result
}

pub fn (c &Client) users_show(user_id string, username string, host string, detailed bool) !User {
	user_id_cstr := if user_id.len > 0 { &char(user_id.str) } else { voidptr(0) }
	username_cstr := if username.len > 0 { &char(username.str) } else { voidptr(0) }
	host_cstr := if host.len > 0 { &char(host.str) } else { voidptr(0) }
	mut cuser := &C.MisskeyUser{}
	C.misskey_user_init(cuser)
	ret := C.misskey_users_show(c.c_client, user_id_cstr, username_cstr, host_cstr, if detailed { 1 } else { 0 }, cuser)
	if ret != 0 {
		return error('users_show failed: ${MisskeyError(ret).detailed(c)}')
	}
	return to_user(cuser)
}

pub fn (c &Client) notes_timeline(limit int, include_local_renotes bool) ![]Note {
	local_val := if include_local_renotes { 1 } else { 0 }
	mut notes_ptr := &C.MisskeyNote(unsafe { nil })
	mut count := 0
	ret := C.misskey_notes_timeline(c.c_client, limit, local_val, &notes_ptr, &count)
	if ret != 0 {
		return error('notes_timeline failed: ${MisskeyError(ret).detailed(c)}')
	}
	
	mut result := []Note{len: count}
	for i := 0; i < count; i++ {
		result[i] = to_note(unsafe { &notes_ptr[i] })
	}
	C.misskey_free_notes(c.c_client, notes_ptr, count)
	return result
}

pub fn (c &Client) notes_local_timeline(limit int) ![]Note {
	mut notes_ptr := &C.MisskeyNote(unsafe { nil })
	mut count := 0
	ret := C.misskey_notes_local_timeline(c.c_client, limit, &notes_ptr, &count)
	if ret != 0 {
		return error('notes_local_timeline failed: ${MisskeyError(ret).detailed(c)}')
	}
	
	mut result := []Note{len: count}
	for i := 0; i < count; i++ {
		result[i] = to_note(unsafe { &notes_ptr[i] })
	}
	C.misskey_free_notes(c.c_client, notes_ptr, count)
	return result
}

fn (c &Client) timeline_opts_to_c(opts TimelineOptions) C.MisskeyTimelineOptions {
	return C.MisskeyTimelineOptions{
		limit: if opts.limit > 0 { opts.limit } else { 20 }
		with_files: if opts.with_files { 1 } else { 0 }
		with_renotes: if opts.with_renotes { 1 } else { 0 }
		with_replies: if opts.with_replies { 1 } else { 0 }
		allow_partial: if opts.allow_partial { 1 } else { 0 }
		since_id: if opts.since_id.len > 0 { &char(opts.since_id.str) } else { voidptr(0) }
		until_id: if opts.until_id.len > 0 { &char(opts.until_id.str) } else { voidptr(0) }
		since_date: opts.since_date
		until_date: opts.until_date
	}
}

pub fn (c &Client) notes_local_timeline_full(opts TimelineOptions) ![]Note {
	mut notes_ptr := &C.MisskeyNote(unsafe { nil })
	mut count := 0
	c_opts := c.timeline_opts_to_c(opts)
	ret := C.misskey_notes_local_timeline_full(c.c_client, &c_opts, &notes_ptr, &count)
	if ret != 0 {
		return error('notes_local_timeline_full failed: ${MisskeyError(ret).detailed(c)}')
	}
	
	mut result := []Note{len: count}
	for i := 0; i < count; i++ {
		result[i] = to_note(unsafe { &notes_ptr[i] })
	}
	C.misskey_free_notes(c.c_client, notes_ptr, count)
	return result
}

pub fn (c &Client) notes_global_timeline(limit int) ![]Note {
	mut notes_ptr := &C.MisskeyNote(unsafe { nil })
	mut count := 0
	ret := C.misskey_notes_global_timeline(c.c_client, limit, &notes_ptr, &count)
	if ret != 0 {
		return error('notes_global_timeline failed: ${MisskeyError(ret).detailed(c)}')
	}
	
	mut result := []Note{len: count}
	for i := 0; i < count; i++ {
		result[i] = to_note(unsafe { &notes_ptr[i] })
	}
	C.misskey_free_notes(c.c_client, notes_ptr, count)
	return result
}

pub fn (c &Client) notes_global_timeline_full(opts TimelineOptions) ![]Note {
	mut notes_ptr := &C.MisskeyNote(unsafe { nil })
	mut count := 0
	c_opts := c.timeline_opts_to_c(opts)
	ret := C.misskey_notes_global_timeline_full(c.c_client, &c_opts, &notes_ptr, &count)
	if ret != 0 {
		return error('notes_global_timeline_full failed: ${MisskeyError(ret).detailed(c)}')
	}
	
	mut result := []Note{len: count}
	for i := 0; i < count; i++ {
		result[i] = to_note(unsafe { &notes_ptr[i] })
	}
	C.misskey_free_notes(c.c_client, notes_ptr, count)
	return result
}

pub fn (c &Client) notes_create(text string, reply_id string, renote_id string) !Note {
	reply_cstr := if reply_id.len > 0 { &char(reply_id.str) } else { voidptr(0) }
	renote_cstr := if renote_id.len > 0 { &char(renote_id.str) } else { voidptr(0) }
	mut cnote := &C.MisskeyNote{}
	C.misskey_note_init(cnote)
	ret := C.misskey_notes_create(c.c_client, &char(text.str), reply_cstr, renote_cstr, cnote)
	if ret != 0 {
		return error('notes_create failed: ${MisskeyError(ret).detailed(c)}')
	}
	return to_note(cnote)
}

pub fn (c &Client) notes_create_full(opts CreateNoteOptions) !Note {
	reply_cstr := if opts.reply_id.len > 0 { &char(opts.reply_id.str) } else { voidptr(0) }
	renote_cstr := if opts.renote_id.len > 0 { &char(opts.renote_id.str) } else { voidptr(0) }
	cw_cstr := if opts.cw.len > 0 { &char(opts.cw.str) } else { voidptr(0) }
	channel_cstr := if opts.channel_id.len > 0 { &char(opts.channel_id.str) } else { voidptr(0) }
	
	mut file_ids_ptr := &char(unsafe { nil })
	if opts.file_ids.len > 0 {
		file_ids_ptr = &char(opts.file_ids[0].str)
	}
	
	mut cnote := &C.MisskeyNote{}
	C.misskey_note_init(cnote)
	ret := C.misskey_notes_create_full(
		c.c_client,
		&char(opts.text.str),
		reply_cstr,
		renote_cstr,
		file_ids_ptr,
		opts.file_ids.len,
		opts.visibility,
		cw_cstr,
		if opts.local_only { 1 } else { 0 },
		channel_cstr,
		if opts.auto_sensitive { 1 } else { 0 },
		if opts.draft { 1 } else { 0 },
		cnote
	)
	if ret != 0 {
		return error('notes_create_full failed: ${MisskeyError(ret).detailed(c)}')
	}
	return to_note(cnote)
}

pub fn (c &Client) notes_show(note_id string) !Note {
	mut cnote := &C.MisskeyNote{}
	C.misskey_note_init(cnote)
	ret := C.misskey_notes_show(c.c_client, &char(note_id.str), cnote)
	if ret != 0 {
		return error('notes_show failed: ${MisskeyError(ret).detailed(c)}')
	}
	return to_note(cnote)
}

pub fn (c &Client) notes_delete(note_id string) ! {
	ret := C.misskey_notes_delete(c.c_client, &char(note_id.str), voidptr(0))
	if ret != 0 {
		return error('notes_delete failed: ${MisskeyError(ret).detailed(c)}')
	}
}

pub fn (c &Client) i_notifications(limit int) ![]Notification {
	mut notif_ptr := &C.MisskeyNotification(unsafe { nil })
	mut count := 0
	ret := C.misskey_i_notifications(c.c_client, limit, &notif_ptr, &count)
	if ret != 0 {
		return error('i_notifications failed: ${MisskeyError(ret).detailed(c)}')
	}
	
	mut result := []Notification{len: count}
	for i := 0; i < count; i++ {
		result[i] = to_notification(unsafe { &notif_ptr[i] })
	}
	C.misskey_free_notifications(c.c_client, notif_ptr, count)
	return result
}

pub fn (c &Client) drive() !DriveInfo {
	mut cinfo := &C.MisskeyDriveInfo{}
	C.misskey_drive_info_init(cinfo)
	ret := C.misskey_drive(c.c_client, cinfo)
	if ret != 0 {
		return error('drive failed: ${MisskeyError(ret).detailed(c)}')
	}
	return DriveInfo{
		capacity: cinfo.capacity
		usage: cinfo.usage
		is_over_quota: cinfo.drive_usage_over_quota != 0
	}
}

pub fn (c &Client) drive_files(limit int, folder_id string) ![]DriveFile {
	folder_cstr := if folder_id.len > 0 { &char(folder_id.str) } else { voidptr(0) }
	mut files_ptr := &C.MisskeyDriveFile(unsafe { nil })
	mut count := 0
	ret := C.misskey_drive_files(c.c_client, limit, folder_cstr, &files_ptr, &count)
	if ret != 0 {
		return error('drive_files failed: ${MisskeyError(ret).detailed(c)}')
	}
	
	mut result := []DriveFile{len: count}
	for i := 0; i < count; i++ {
		result[i] = to_drive_file(unsafe { &files_ptr[i] })
	}
	C.misskey_free_drive_files(c.c_client, files_ptr, count)
	return result
}

pub fn (c &Client) drive_files_create(file_path string, folder_id string, name string) !DriveFile {
	folder_cstr := if folder_id.len > 0 { &char(folder_id.str) } else { voidptr(0) }
	name_cstr := if name.len > 0 { &char(name.str) } else { voidptr(0) }
	mut cfile := &C.MisskeyDriveFile{}
	C.misskey_drive_file_init(cfile)
	ret := C.misskey_drive_files_create(c.c_client, &char(file_path.str), folder_cstr, name_cstr, cfile)
	if ret != 0 {
		return error('drive_files_create failed: ${MisskeyError(ret).detailed(c)}')
	}
	return to_drive_file(cfile)
}

pub fn (c &Client) drive_files_delete(file_id string) ! {
	ret := C.misskey_drive_files_delete(c.c_client, &char(file_id.str), voidptr(0))
	if ret != 0 {
		return error('drive_files_delete failed: ${MisskeyError(ret).detailed(c)}')
	}
}

pub fn (c &Client) drive_folders(limit int, folder_id string) ![]DriveFolder {
	folder_cstr := if folder_id.len > 0 { &char(folder_id.str) } else { voidptr(0) }
	mut folders_ptr := &C.MisskeyDriveFolder(unsafe { nil })
	mut count := 0
	ret := C.misskey_drive_folders(c.c_client, limit, folder_cstr, &folders_ptr, &count)
	if ret != 0 {
		return error('drive_folders failed: ${MisskeyError(ret).detailed(c)}')
	}
	
	mut result := []DriveFolder{len: count}
	for i := 0; i < count; i++ {
		result[i] = to_drive_folder(unsafe { &folders_ptr[i] })
	}
	C.misskey_free_drive_folders(c.c_client, folders_ptr, count)
	return result
}

pub fn (c &Client) translate(note_id string, target_lang string) !TranslateResult {
	mut cresult := &C.MisskeyTranslateResult{}
	C.misskey_translate_result_init(cresult)
	ret := C.misskey_translate(c.c_client, &char(note_id.str), &char(target_lang.str), cresult)
	if ret != 0 {
		return error('translate failed: ${MisskeyError(ret).detailed(c)}')
	}
	return TranslateResult{
		text: unsafe { cstring_to_vstring(&char(cresult.text)) }
		source_lang: unsafe { cstring_to_vstring(&char(cresult.source_lang)) }
		target_lang: unsafe { cstring_to_vstring(&char(cresult.target_lang)) }
	}
}

pub fn (c &Client) clips_list() ![]Clip {
	mut clips_ptr := &C.MisskeyClip(unsafe { nil })
	mut count := 0
	ret := C.misskey_clips_list(c.c_client, &clips_ptr, &count)
	if ret != 0 {
		return error('clips_list failed: ${MisskeyError(ret).detailed(c)}')
	}
	
	mut result := []Clip{len: count}
	for i := 0; i < count; i++ {
		result[i] = to_clip(unsafe { &clips_ptr[i] })
	}
	C.misskey_free_clips(c.c_client, clips_ptr, count)
	return result
}

pub fn (c &Client) clips_create(name string, description string, is_public bool) !Clip {
	desc_cstr := if description.len > 0 { &char(description.str) } else { voidptr(0) }
	mut cclip := &C.MisskeyClip{}
	C.misskey_clip_init(cclip)
	ret := C.misskey_clips_create(c.c_client, &char(name.str), desc_cstr, if is_public { 1 } else { 0 }, cclip)
	if ret != 0 {
		return error('clips_create failed: ${MisskeyError(ret).detailed(c)}')
	}
	return to_clip(cclip)
}

pub fn (c &Client) clips_delete(clip_id string) ! {
	ret := C.misskey_clips_delete(c.c_client, &char(clip_id.str), voidptr(0))
	if ret != 0 {
		return error('clips_delete failed: ${MisskeyError(ret).detailed(c)}')
	}
}

pub type StreamEventHandler = fn (msg_type string, body string)

@[heap]
pub struct Stream {
mut:
	c_stream &C.MisskeyStream
	handler StreamEventHandler
}

pub fn stream_new(host string, token string) !Stream {
	c_stream := C.misskey_stream_new(&char(host.str), &char(token.str))
	if c_stream == unsafe { nil } {
		return error('failed to create stream')
	}
	return Stream{
		c_stream: c_stream
	}
}

pub fn (s &Stream) freeit() {
	C.misskey_stream_free(s.c_stream)
}

pub fn (s &Stream) connect(channel StreamChannel, channel_id string) ! {
	ret := C.misskey_stream_connect(s.c_stream, int(channel), &char(channel_id.str))
	if ret != 0 {
		return error('failed to connect to stream channel: ${MisskeyError(ret)}')
	}
}

pub fn (s &Stream) disconnect(channel_id string) ! {
	ret := C.misskey_stream_disconnect(s.c_stream, &char(channel_id.str))
	if ret != 0 {
		return error('failed to disconnect from stream channel: ${MisskeyError(ret)}')
	}
}

pub fn (s &Stream) subscribe_note(note_id string) ! {
	ret := C.misskey_stream_subscribe_note(s.c_stream, &char(note_id.str))
	if ret != 0 {
		return error('failed to subscribe to note: ${MisskeyError(ret)}')
	}
}

pub fn (s &Stream) unsubscribe_note(note_id string) ! {
	ret := C.misskey_stream_unsubscribe_note(s.c_stream, &char(note_id.str))
	if ret != 0 {
		return error('failed to unsubscribe from note: ${MisskeyError(ret)}')
	}
}

pub fn (s &Stream) poll(timeout_ms int) ! {
	ret := C.misskey_stream_poll(s.c_stream, timeout_ms)
	if ret != 0 {
		return error('stream poll failed: ${MisskeyError(ret)}')
	}
}

pub fn (s &Stream) set_handler(handler StreamEventHandler) {
	s.handler = handler
}
