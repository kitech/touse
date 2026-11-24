// ABI 层：全部 struct 字段顺序严格对齐 opendal_dyn.c 内嵌类型。
module opendal

import vcp.tcchf

// V 只输出 C 函数调用，不输出 C 声明；用 opendal.h 提供 ABI 类型与原型。
#include <opendal.h>

// ---------- C 类型镜像 ----------
struct C.opendal_bytes {
	data &u8
	len usize
	capacity usize
}

struct C.opendal_error {
	code int
	message C.opendal_bytes
}

struct C.opendal_entry {
	inner voidptr
}

struct C.opendal_result_lister_next {
	entry &C.opendal_entry
	error &C.opendal_error
}

struct C.opendal_lister {
	inner voidptr
}

struct C.opendal_operator_layers {
	inner voidptr
}

struct C.opendal_metadata {
	inner voidptr
}

struct C.opendal_metadata_user_metadata {
	inner voidptr
}

struct C.opendal_metadata_user_metadata_pair {
	key &char
	value &char
}

struct C.opendal_operator {
	inner voidptr
}

struct C.opendal_result_operator_new {
	op &C.opendal_operator
	error &C.opendal_error
}

struct C.opendal_operator_options {
	inner voidptr
}

struct C.opendal_write_user_metadata_pair {
	key &char
	value &char
}

struct C.opendal_write_options {
	append bool
	cache_control &char
	content_type &char
	content_disposition &char
	content_encoding &char
	if_match &char
	if_none_match &char
	if_not_exists bool
	concurrent usize
	has_chunk bool
	chunk usize
	user_metadata &C.opendal_write_user_metadata_pair
	user_metadata_len usize
}

struct C.opendal_result_write {
	meta &C.opendal_metadata
	error &C.opendal_error
}

struct C.opendal_result_read {
	data C.opendal_bytes
	error &C.opendal_error
}

struct C.opendal_read_options {
	offset u64
	has_length bool
	length u64
	version &char
	if_match &char
	if_none_match &char
	has_if_modified_since bool
	if_modified_since i64
	has_if_unmodified_since bool
	if_unmodified_since i64
	concurrent usize
	has_chunk bool
	chunk usize
	has_gap bool
	gap usize
	has_content_length_hint bool
	content_length_hint u64
	override_content_type &char
	override_cache_control &char
	override_content_disposition &char
}

struct C.opendal_reader {
	inner voidptr
}

struct C.opendal_result_operator_reader {
	reader &C.opendal_reader
	error &C.opendal_error
}

struct C.opendal_reader_options {
	version &char
	if_match &char
	if_none_match &char
	has_if_modified_since bool
	if_modified_since i64
	has_if_unmodified_since bool
	if_unmodified_since i64
	has_content_length_hint bool
	content_length_hint u64
	concurrent usize
	has_chunk bool
	chunk usize
	has_gap bool
	gap usize
	prefetch usize
}

struct C.opendal_writer {
	inner voidptr
}

struct C.opendal_result_operator_writer {
	writer &C.opendal_writer
	error &C.opendal_error
}

struct C.opendal_delete_options {
	version &char
	recursive bool
}

struct C.opendal_result_is_exist {
	is_exist bool
	error &C.opendal_error
}

struct C.opendal_result_exists {
	exists bool
	error &C.opendal_error
}

struct C.opendal_result_stat {
	meta &C.opendal_metadata
	error &C.opendal_error
}

struct C.opendal_stat_options {
	version &char
	if_match &char
	if_none_match &char
	has_if_modified_since bool
	if_modified_since i64
	has_if_unmodified_since bool
	if_unmodified_since i64
	override_content_type &char
	override_cache_control &char
	override_content_disposition &char
}

struct C.opendal_result_list {
	lister &C.opendal_lister
	error &C.opendal_error
}

struct C.opendal_list_options {
	recursive bool
	limit usize
	start_after &char
	versions bool
	deleted bool
}

struct C.opendal_copy_options {
	if_not_exists bool
	if_match &char
	source_version &char
	has_source_content_length_hint bool
	source_content_length_hint u64
	concurrent usize
	has_chunk bool
	chunk usize
}

struct C.opendal_copier {
	inner voidptr
}

struct C.opendal_result_operator_copier {
	copier &C.opendal_copier
	error &C.opendal_error
}

struct C.opendal_operator_info {
	inner voidptr
}

struct C.opendal_capability {
	stat bool
	stat_with_if_match bool
	stat_with_if_none_match bool
	stat_with_if_modified_since bool
	stat_with_if_unmodified_since bool
	stat_with_override_cache_control bool
	stat_with_override_content_disposition bool
	stat_with_override_content_type bool
	stat_with_version bool
	read bool
	read_with_if_match bool
	read_with_if_none_match bool
	read_with_override_cache_control bool
	read_with_override_content_disposition bool
	read_with_override_content_type bool
	read_with_if_modified_since bool
	read_with_if_unmodified_since bool
	read_with_version bool
	write bool
	write_can_multi bool
	write_can_empty bool
	write_can_append bool
	write_with_content_type bool
	write_with_content_disposition bool
	write_with_content_encoding bool
	write_with_cache_control bool
	write_with_if_match bool
	write_with_if_none_match bool
	write_with_if_not_exists bool
	write_with_user_metadata bool
	write_multi_max_size usize
	write_multi_min_size usize
	write_total_max_size usize
	create_dir bool
	delete_ bool
	delete_with_version bool
	delete_with_recursive bool
	copy bool
	copy_with_if_not_exists bool
	copy_with_if_match bool
	copy_with_source_version bool
	copy_can_multi bool
	copy_multi_max_size usize
	copy_multi_min_size usize
	rename bool
	list bool
	list_with_limit bool
	list_with_start_after bool
	list_with_recursive bool
	list_with_versions bool
	list_with_deleted bool
	presign bool
	presign_read bool
	presign_stat bool
	presign_write bool
	presign_delete bool
	shared bool
}

struct C.opendal_presigned_request {
	inner voidptr
}

struct C.opendal_result_presign {
	req &C.opendal_presigned_request
	error &C.opendal_error
}

struct C.opendal_http_header_pair {
	key &char
	value &char
}

struct C.opendal_result_reader_read {
	size usize
	error &C.opendal_error
}

struct C.opendal_result_reader_seek {
	pos u64
	error &C.opendal_error
}

struct C.opendal_result_writer_write {
	size usize
	error &C.opendal_error
}

struct C.opendal_result_copier_next {
	size usize
	has_next bool
	error &C.opendal_error
}

// ---------- 全部 extern（按 C 头顺序） ----------
fn C.opendal_error_free(ptr &C.opendal_error)
fn C.opendal_lister_next(self &C.opendal_lister) C.opendal_result_lister_next
fn C.opendal_lister_free(ptr &C.opendal_lister)
fn C.opendal_operator_layers_new() &C.opendal_operator_layers
fn C.opendal_operator_layers_add_retry(self &C.opendal_operator_layers, jitter bool, factor f32, min_delay_ns u64, max_delay_ns u64, max_times u64)
fn C.opendal_operator_layers_add_timeout(self &C.opendal_operator_layers, timeout_ns u64, io_timeout_ns u64)
fn C.opendal_operator_layers_free(ptr &C.opendal_operator_layers)
fn C.opendal_metadata_free(ptr &C.opendal_metadata)
fn C.opendal_metadata_mode(self &C.opendal_metadata) u8
fn C.opendal_metadata_content_length(self &C.opendal_metadata) u64
fn C.opendal_metadata_is_file(self &C.opendal_metadata) bool
fn C.opendal_metadata_is_dir(self &C.opendal_metadata) bool
fn C.opendal_metadata_is_current(self &C.opendal_metadata) u8
fn C.opendal_metadata_is_deleted(self &C.opendal_metadata) bool
fn C.opendal_metadata_cache_control(self &C.opendal_metadata) &char
fn C.opendal_metadata_content_disposition(self &C.opendal_metadata) &char
fn C.opendal_metadata_content_md5(self &C.opendal_metadata) &char
fn C.opendal_metadata_content_type(self &C.opendal_metadata) &char
fn C.opendal_metadata_content_encoding(self &C.opendal_metadata) &char
fn C.opendal_metadata_etag(self &C.opendal_metadata) &char
fn C.opendal_metadata_version(self &C.opendal_metadata) &char
fn C.opendal_metadata_get_user_metadata(self &C.opendal_metadata) &C.opendal_metadata_user_metadata
fn C.opendal_metadata_last_modified_ms(self &C.opendal_metadata) i64
fn C.opendal_metadata_user_metadata_pairs(metadata &C.opendal_metadata_user_metadata) &C.opendal_metadata_user_metadata_pair
fn C.opendal_metadata_user_metadata_len(metadata &C.opendal_metadata_user_metadata) usize
fn C.opendal_metadata_user_metadata_free(metadata &C.opendal_metadata_user_metadata)
fn C.opendal_operator_free(ptr &C.opendal_operator)
fn C.opendal_operator_new(scheme &char, options &C.opendal_operator_options) C.opendal_result_operator_new
fn C.opendal_operator_new_with_layers(scheme &char, options &C.opendal_operator_options, layers &C.opendal_operator_layers) C.opendal_result_operator_new
fn C.opendal_operator_write(op &C.opendal_operator, path &char, bytes &C.opendal_bytes) &C.opendal_error
fn C.opendal_operator_write_with(op &C.opendal_operator, path &char, bytes &C.opendal_bytes, opts &C.opendal_write_options) &C.opendal_error
fn C.opendal_operator_write_with_metadata(op &C.opendal_operator, path &char, bytes &C.opendal_bytes, opts &C.opendal_write_options) C.opendal_result_write
fn C.opendal_operator_read(op &C.opendal_operator, path &char) C.opendal_result_read
fn C.opendal_operator_read_with(op &C.opendal_operator, path &char, opts &C.opendal_read_options) C.opendal_result_read
fn C.opendal_operator_reader(op &C.opendal_operator, path &char) C.opendal_result_operator_reader
fn C.opendal_operator_reader_with(op &C.opendal_operator, path &char, opts &C.opendal_reader_options) C.opendal_result_operator_reader
fn C.opendal_operator_writer(op &C.opendal_operator, path &char) C.opendal_result_operator_writer
fn C.opendal_operator_writer_with(op &C.opendal_operator, path &char, opts &C.opendal_write_options) C.opendal_result_operator_writer
fn C.opendal_operator_delete(op &C.opendal_operator, path &char) &C.opendal_error
fn C.opendal_operator_delete_with(op &C.opendal_operator, path &char, opts &C.opendal_delete_options) &C.opendal_error
fn C.opendal_operator_is_exist(op &C.opendal_operator, path &char) C.opendal_result_is_exist
fn C.opendal_operator_exists(op &C.opendal_operator, path &char) C.opendal_result_exists
fn C.opendal_operator_stat(op &C.opendal_operator, path &char) C.opendal_result_stat
fn C.opendal_operator_stat_with(op &C.opendal_operator, path &char, opts &C.opendal_stat_options) C.opendal_result_stat
fn C.opendal_operator_list(op &C.opendal_operator, path &char) C.opendal_result_list
fn C.opendal_operator_list_with(op &C.opendal_operator, path &char, opts &C.opendal_list_options) C.opendal_result_list
fn C.opendal_operator_create_dir(op &C.opendal_operator, path &char) &C.opendal_error
fn C.opendal_operator_rename(op &C.opendal_operator, src &char, dest &char) &C.opendal_error
fn C.opendal_operator_copy(op &C.opendal_operator, src &char, dest &char) &C.opendal_error
fn C.opendal_operator_copy_with(op &C.opendal_operator, src &char, dest &char, opts &C.opendal_copy_options) &C.opendal_error
fn C.opendal_operator_check(op &C.opendal_operator) &C.opendal_error
fn C.opendal_operator_copier(op &C.opendal_operator, src &char, dest &char) C.opendal_result_operator_copier
fn C.opendal_operator_copier_with(op &C.opendal_operator, src &char, dest &char, opts &C.opendal_copy_options) C.opendal_result_operator_copier
fn C.opendal_operator_info_new(op &C.opendal_operator) &C.opendal_operator_info
fn C.opendal_operator_info_free(ptr &C.opendal_operator_info)
fn C.opendal_operator_info_get_scheme(self &C.opendal_operator_info) &char
fn C.opendal_operator_info_get_root(self &C.opendal_operator_info) &char
fn C.opendal_operator_info_get_name(self &C.opendal_operator_info) &char
fn C.opendal_operator_info_get_capability(self &C.opendal_operator_info) C.opendal_capability
fn C.opendal_operator_presign_read(op &C.opendal_operator, path &char, expire_secs u64) C.opendal_result_presign
fn C.opendal_operator_presign_read_with(op &C.opendal_operator, path &char, expire_secs u64, opts &C.opendal_read_options) C.opendal_result_presign
fn C.opendal_operator_presign_write(op &C.opendal_operator, path &char, expire_secs u64) C.opendal_result_presign
fn C.opendal_operator_presign_write_with(op &C.opendal_operator, path &char, expire_secs u64, opts &C.opendal_write_options) C.opendal_result_presign
fn C.opendal_operator_presign_delete(op &C.opendal_operator, path &char, expire_secs u64) C.opendal_result_presign
fn C.opendal_operator_presign_delete_with(op &C.opendal_operator, path &char, expire_secs u64, opts &C.opendal_delete_options) C.opendal_result_presign
fn C.opendal_operator_presign_stat(op &C.opendal_operator, path &char, expire_secs u64) C.opendal_result_presign
fn C.opendal_operator_presign_stat_with(op &C.opendal_operator, path &char, expire_secs u64, opts &C.opendal_stat_options) C.opendal_result_presign
fn C.opendal_presigned_request_method(req &C.opendal_presigned_request) &char
fn C.opendal_presigned_request_uri(req &C.opendal_presigned_request) &char
fn C.opendal_presigned_request_headers(req &C.opendal_presigned_request) &C.opendal_http_header_pair
fn C.opendal_presigned_request_headers_len(req &C.opendal_presigned_request) usize
fn C.opendal_presigned_request_free(req &C.opendal_presigned_request)
fn C.opendal_string_free(ptr &char)
fn C.opendal_bytes_free(ptr &C.opendal_bytes)
fn C.opendal_list_options_new() &C.opendal_list_options
fn C.opendal_list_options_set_recursive(opts &C.opendal_list_options, recursive bool)
fn C.opendal_list_options_set_limit(opts &C.opendal_list_options, limit usize)
fn C.opendal_list_options_set_start_after(opts &C.opendal_list_options, start_after &char)
fn C.opendal_list_options_set_versions(opts &C.opendal_list_options, versions bool)
fn C.opendal_list_options_set_deleted(opts &C.opendal_list_options, deleted bool)
fn C.opendal_list_options_free(opts &C.opendal_list_options)
fn C.opendal_delete_options_new() &C.opendal_delete_options
fn C.opendal_delete_options_set_version(opts &C.opendal_delete_options, version &char)
fn C.opendal_delete_options_set_recursive(opts &C.opendal_delete_options, recursive bool)
fn C.opendal_delete_options_free(opts &C.opendal_delete_options)
fn C.opendal_write_options_new() &C.opendal_write_options
fn C.opendal_write_options_free(opts &C.opendal_write_options)
fn C.opendal_write_options_set_append(opts &C.opendal_write_options, append bool)
fn C.opendal_write_options_set_cache_control(opts &C.opendal_write_options, cache_control &char)
fn C.opendal_write_options_set_content_type(opts &C.opendal_write_options, content_type &char)
fn C.opendal_write_options_set_content_disposition(opts &C.opendal_write_options, content_disposition &char)
fn C.opendal_write_options_set_content_encoding(opts &C.opendal_write_options, content_encoding &char)
fn C.opendal_write_options_set_if_match(opts &C.opendal_write_options, if_match &char)
fn C.opendal_write_options_set_if_none_match(opts &C.opendal_write_options, if_none_match &char)
fn C.opendal_write_options_set_if_not_exists(opts &C.opendal_write_options, if_not_exists bool)
fn C.opendal_write_options_set_concurrent(opts &C.opendal_write_options, concurrent usize)
fn C.opendal_write_options_set_chunk(opts &C.opendal_write_options, chunk usize)
fn C.opendal_write_options_set_user_metadata(opts &C.opendal_write_options, pairs &C.opendal_write_user_metadata_pair, len usize)
fn C.opendal_stat_options_new() &C.opendal_stat_options
fn C.opendal_stat_options_free(opts &C.opendal_stat_options)
fn C.opendal_stat_options_set_version(opts &C.opendal_stat_options, v &char)
fn C.opendal_stat_options_set_if_match(opts &C.opendal_stat_options, v &char)
fn C.opendal_stat_options_set_if_none_match(opts &C.opendal_stat_options, v &char)
fn C.opendal_stat_options_set_if_modified_since(opts &C.opendal_stat_options, v i64)
fn C.opendal_stat_options_set_if_unmodified_since(opts &C.opendal_stat_options, v i64)
fn C.opendal_stat_options_set_override_content_type(opts &C.opendal_stat_options, v &char)
fn C.opendal_stat_options_set_override_cache_control(opts &C.opendal_stat_options, v &char)
fn C.opendal_stat_options_set_override_content_disposition(opts &C.opendal_stat_options, v &char)
fn C.opendal_read_options_new() &C.opendal_read_options
fn C.opendal_read_options_free(opts &C.opendal_read_options)
fn C.opendal_read_options_set_range(opts &C.opendal_read_options, offset u64, length u64)
fn C.opendal_read_options_set_range_from(opts &C.opendal_read_options, offset u64)
fn C.opendal_read_options_set_version(opts &C.opendal_read_options, v &char)
fn C.opendal_read_options_set_if_match(opts &C.opendal_read_options, v &char)
fn C.opendal_read_options_set_if_none_match(opts &C.opendal_read_options, v &char)
fn C.opendal_read_options_set_if_modified_since(opts &C.opendal_read_options, v i64)
fn C.opendal_read_options_set_if_unmodified_since(opts &C.opendal_read_options, v i64)
fn C.opendal_read_options_set_concurrent(opts &C.opendal_read_options, v usize)
fn C.opendal_read_options_set_chunk(opts &C.opendal_read_options, v usize)
fn C.opendal_read_options_set_gap(opts &C.opendal_read_options, v usize)
fn C.opendal_read_options_set_content_length_hint(opts &C.opendal_read_options, v u64)
fn C.opendal_read_options_set_override_content_type(opts &C.opendal_read_options, v &char)
fn C.opendal_read_options_set_override_cache_control(opts &C.opendal_read_options, v &char)
fn C.opendal_read_options_set_override_content_disposition(opts &C.opendal_read_options, v &char)
fn C.opendal_reader_options_new() &C.opendal_reader_options
fn C.opendal_reader_options_free(opts &C.opendal_reader_options)
fn C.opendal_reader_options_set_version(opts &C.opendal_reader_options, v &char)
fn C.opendal_reader_options_set_if_match(opts &C.opendal_reader_options, v &char)
fn C.opendal_reader_options_set_if_none_match(opts &C.opendal_reader_options, v &char)
fn C.opendal_reader_options_set_if_modified_since(opts &C.opendal_reader_options, v i64)
fn C.opendal_reader_options_set_if_unmodified_since(opts &C.opendal_reader_options, v i64)
fn C.opendal_reader_options_set_content_length_hint(opts &C.opendal_reader_options, v u64)
fn C.opendal_reader_options_set_concurrent(opts &C.opendal_reader_options, v usize)
fn C.opendal_reader_options_set_chunk(opts &C.opendal_reader_options, v usize)
fn C.opendal_reader_options_set_gap(opts &C.opendal_reader_options, v usize)
fn C.opendal_reader_options_set_prefetch(opts &C.opendal_reader_options, v usize)
fn C.opendal_copy_options_new() &C.opendal_copy_options
fn C.opendal_copy_options_free(opts &C.opendal_copy_options)
fn C.opendal_copy_options_set_if_not_exists(opts &C.opendal_copy_options, v bool)
fn C.opendal_copy_options_set_if_match(opts &C.opendal_copy_options, v &char)
fn C.opendal_copy_options_set_source_version(opts &C.opendal_copy_options, v &char)
fn C.opendal_copy_options_set_source_content_length_hint(opts &C.opendal_copy_options, v u64)
fn C.opendal_copy_options_set_concurrent(opts &C.opendal_copy_options, v usize)
fn C.opendal_copy_options_set_chunk(opts &C.opendal_copy_options, v usize)
fn C.opendal_operator_options_new() &C.opendal_operator_options
fn C.opendal_operator_options_set(self &C.opendal_operator_options, key &char, value &char)
fn C.opendal_operator_options_free(ptr &C.opendal_operator_options)
fn C.opendal_entry_path(self &C.opendal_entry) &char
fn C.opendal_entry_name(self &C.opendal_entry) &char
fn C.opendal_entry_metadata(self &C.opendal_entry) &C.opendal_metadata
fn C.opendal_entry_free(ptr &C.opendal_entry)
fn C.opendal_reader_read(self &C.opendal_reader, buf &u8, len usize) C.opendal_result_reader_read
fn C.opendal_reader_seek(self &C.opendal_reader, offset i64, whence i32) C.opendal_result_reader_seek
fn C.opendal_reader_free(ptr &C.opendal_reader)
fn C.opendal_writer_write(self &C.opendal_writer, bytes &C.opendal_bytes) C.opendal_result_writer_write
fn C.opendal_writer_close(ptr &C.opendal_writer) &C.opendal_error
fn C.opendal_writer_close_with_metadata(ptr &C.opendal_writer) C.opendal_result_write
fn C.opendal_writer_free(ptr &C.opendal_writer)
fn C.opendal_copier_next(self &C.opendal_copier) C.opendal_result_copier_next
fn C.opendal_copier_abort(self &C.opendal_copier) &C.opendal_error
fn C.opendal_copier_free(ptr &C.opendal_copier)
fn C.memcpy(dst voidptr, src voidptr, n usize) voidptr

// ---------- 公共错误 / 安全原语 ----------
pub enum Code {
	unexpected
	unsupported
	config_invalid
	not_found
	permission_denied
	is_a_directory
	not_a_directory
	already_exists
	rate_limited
	is_same_file
	condition_not_match
	range_not_satisfied
	conflict
}

pub struct OpError {
pub:
	kind Code
	message string
}

fn (e OpError) code() int {
	return int(e.kind)
}

fn (e OpError) msg() string {
	return e.message
}

pub const (
	seek_set = 0
	seek_cur = 1
	seek_end = 2
)

pub fn take_error(e &C.opendal_error) OpError {
	code := Code(int(e.code))
	mut message := ''
	if e.message.len > 0 && e.message.data != unsafe { nil } {
		message = unsafe { e.message.data.vstring_with_len(int(e.message.len)).clone() }
	}
	C.opendal_error_free(e)
	return OpError{ kind: code, message: message }
}

pub fn ok_or_error(e &C.opendal_error) ! {
	if !isnil(e) {
		return take_error(e)
	}
}

pub fn take_string(p &char) string {
	if isnil(p) {
		return ''
	}
	s := cstring_to_vstring(p)
	C.opendal_string_free(p)
	return s
}

pub fn borrow_string(p &char) string {
	if isnil(p) {
		return ''
	}
	return cstring_to_vstring(p)
}

pub fn take_bytes(b &C.opendal_bytes) []u8 {
	mut out := []u8{len: int(b.len)}
	if b.len > 0 && b.data != unsafe { nil } {
		unsafe { C.memcpy(out.data, b.data, b.len) }
	}
	C.opendal_bytes_free(b)
	return out
}

pub fn cbytes(data []u8) C.opendal_bytes {
	mut ptr := data.data
	if data.len == 0 {
		ptr = unsafe { nil }
	}
	return C.opendal_bytes{
		data: ptr
		len: usize(data.len)
		capacity: usize(data.len)
	}
}
