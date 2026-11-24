// 高层类型化 API；风格与 rclone/method_api.v 一致。
module opendal

pub enum PresignKind {
	read
	write
	delete
	stat
}

// ---------- 内部：可选 options → C 指针 ----------
fn wopt(o ?WriteOptions) &C.opendal_write_options {
	if x := o {
		return x.h
	}
	return unsafe { nil }
}

fn ropt(o ?ReadOptions) &C.opendal_read_options {
	if x := o {
		return x.h
	}
	return unsafe { nil }
}

fn rdopt(o ?ReaderOptions) &C.opendal_reader_options {
	if x := o {
		return x.h
	}
	return unsafe { nil }
}

fn sopt(o ?StatOptions) &C.opendal_stat_options {
	if x := o {
		return x.h
	}
	return unsafe { nil }
}

fn lopt(o ?ListOptions) &C.opendal_list_options {
	if x := o {
		return x.h
	}
	return unsafe { nil }
}

fn dopt(o ?DeleteOptions) &C.opendal_delete_options {
	if x := o {
		return x.h
	}
	return unsafe { nil }
}

fn copt(o ?CopyOptions) &C.opendal_copy_options {
	if x := o {
		return x.h
	}
	return unsafe { nil }
}

fn layeropt(o ?Layers) &C.opendal_operator_layers {
	if x := o {
		return x.h
	}
	return unsafe { nil }
}

fn meta_result(r C.opendal_result_write) !Metadata {
	ok_or_error(r.error) or { return err }
	if isnil(r.meta) {
		return error('write_with_metadata: null metadata')
	}
	return Metadata{ h: r.meta }
}

fn stat_result(r C.opendal_result_stat) !Metadata {
	ok_or_error(r.error) or { return err }
	if isnil(r.meta) {
		return error('stat: null metadata')
	}
	return Metadata{ h: r.meta }
}

fn read_result(r C.opendal_result_read) ![]u8 {
	ok_or_error(r.error) or { return err }
	return take_bytes(&r.data)
}

fn reader_result(r C.opendal_result_operator_reader) !Reader {
	ok_or_error(r.error) or { return err }
	if isnil(r.reader) {
		return error('reader: null handle')
	}
	return Reader{ h: r.reader }
}

fn writer_result(r C.opendal_result_operator_writer) !Writer {
	ok_or_error(r.error) or { return err }
	if isnil(r.writer) {
		return error('writer: null handle')
	}
	return Writer{ h: r.writer }
}

fn list_result(r C.opendal_result_list) !Lister {
	ok_or_error(r.error) or { return err }
	if isnil(r.lister) {
		return error('list: null lister')
	}
	return Lister{ h: r.lister }
}

fn copier_result(r C.opendal_result_operator_copier) !Copier {
	ok_or_error(r.error) or { return err }
	if isnil(r.copier) {
		return error('copier: null handle')
	}
	return Copier{ h: r.copier }
}

fn presign_result(r C.opendal_result_presign) !PresignedRequest {
	ok_or_error(r.error) or { return err }
	if isnil(r.req) {
		return error('presign: null request')
	}
	return PresignedRequest{ h: r.req }
}

// ---------- Layers ----------
pub struct Layers {
mut:
	h &C.opendal_operator_layers = unsafe { nil }
}

pub fn (l &Layers) init() ! {
	l.h = C.opendal_operator_layers_new()
	if isnil(l.h) {
		return error('layers_new failed')
	}
}

pub fn (l &Layers) add_retry(jitter bool, factor f32, min_delay_ns u64, max_delay_ns u64, max_times u64) {
	if !isnil(l.h) {
		C.opendal_operator_layers_add_retry(l.h, jitter, factor, min_delay_ns, max_delay_ns, max_times)
	}
}

pub fn (l &Layers) add_timeout(timeout_ns u64, io_timeout_ns u64) {
	if !isnil(l.h) {
		C.opendal_operator_layers_add_timeout(l.h, timeout_ns, io_timeout_ns)
	}
}

pub fn (l &Layers) free() {
	if !isnil(l.h) {
		C.opendal_operator_layers_free(l.h)
		l.h = unsafe { nil }
	}
}

// ---------- Options（8 种） ----------
pub struct OperatorOptions {
mut:
	h &C.opendal_operator_options = unsafe { nil }
}

pub fn (o &OperatorOptions) init() ! {
	o.h = C.opendal_operator_options_new()
	if isnil(o.h) {
		return error('operator_options_new failed')
	}
}

pub fn (o &OperatorOptions) set(k string, v string) {
	if !isnil(o.h) {
		C.opendal_operator_options_set(o.h, k.str, v.str)
	}
}

pub fn (o &OperatorOptions) free() {
	if !isnil(o.h) {
		C.opendal_operator_options_free(o.h)
		o.h = unsafe { nil }
	}
}

pub struct WriteOptions {
mut:
	h &C.opendal_write_options = unsafe { nil }
}

pub fn (o &WriteOptions) init() ! {
	o.h = C.opendal_write_options_new()
	if isnil(o.h) {
		return error('write_options_new failed')
	}
}

pub fn (o &WriteOptions) free() {
	if !isnil(o.h) {
		C.opendal_write_options_free(o.h)
		o.h = unsafe { nil }
	}
}

pub fn (o &WriteOptions) set_append(v bool) {
	if !isnil(o.h) { C.opendal_write_options_set_append(o.h, v) }
}

pub fn (o &WriteOptions) set_cache_control(v string) {
	if !isnil(o.h) { C.opendal_write_options_set_cache_control(o.h, v.str) }
}

pub fn (o &WriteOptions) set_content_type(v string) {
	if !isnil(o.h) { C.opendal_write_options_set_content_type(o.h, v.str) }
}

pub fn (o &WriteOptions) set_content_disposition(v string) {
	if !isnil(o.h) { C.opendal_write_options_set_content_disposition(o.h, v.str) }
}

pub fn (o &WriteOptions) set_content_encoding(v string) {
	if !isnil(o.h) { C.opendal_write_options_set_content_encoding(o.h, v.str) }
}

pub fn (o &WriteOptions) set_if_match(v string) {
	if !isnil(o.h) { C.opendal_write_options_set_if_match(o.h, v.str) }
}

pub fn (o &WriteOptions) set_if_none_match(v string) {
	if !isnil(o.h) { C.opendal_write_options_set_if_none_match(o.h, v.str) }
}

pub fn (o &WriteOptions) set_if_not_exists(v bool) {
	if !isnil(o.h) { C.opendal_write_options_set_if_not_exists(o.h, v) }
}

pub fn (o &WriteOptions) set_concurrent(v usize) {
	if !isnil(o.h) { C.opendal_write_options_set_concurrent(o.h, v) }
}

pub fn (o &WriteOptions) set_chunk(v usize) {
	if !isnil(o.h) { C.opendal_write_options_set_chunk(o.h, v) }
}

pub fn (o &WriteOptions) set_user_metadata(m map[string]string) {
	if isnil(o.h) || m.len == 0 { return }
	mut pairs := []C.opendal_write_user_metadata_pair{len: m.len}
	mut i := 0
	for k, v in m {
		pairs[i] = C.opendal_write_user_metadata_pair{ key: k.str, value: v.str }
		i++
	}
	C.opendal_write_options_set_user_metadata(o.h, pairs.data, pairs.len)
}

pub struct ReadOptions {
mut:
	h &C.opendal_read_options = unsafe { nil }
}

pub fn (o &ReadOptions) init() ! {
	o.h = C.opendal_read_options_new()
	if isnil(o.h) { return error('read_options_new failed') }
}

pub fn (o &ReadOptions) free() {
	if !isnil(o.h) { C.opendal_read_options_free(o.h); o.h = unsafe { nil } }
}

pub fn (o &ReadOptions) set_range(offset u64, length u64) {
	if !isnil(o.h) { C.opendal_read_options_set_range(o.h, offset, length) }
}

pub fn (o &ReadOptions) set_range_from(offset u64) {
	if !isnil(o.h) { C.opendal_read_options_set_range_from(o.h, offset) }
}

pub fn (o &ReadOptions) set_version(v string) {
	if !isnil(o.h) { C.opendal_read_options_set_version(o.h, v.str) }
}

pub fn (o &ReadOptions) set_if_match(v string) {
	if !isnil(o.h) { C.opendal_read_options_set_if_match(o.h, v.str) }
}

pub fn (o &ReadOptions) set_if_none_match(v string) {
	if !isnil(o.h) { C.opendal_read_options_set_if_none_match(o.h, v.str) }
}

pub fn (o &ReadOptions) set_if_modified_since(v i64) {
	if !isnil(o.h) { C.opendal_read_options_set_if_modified_since(o.h, v) }
}

pub fn (o &ReadOptions) set_if_unmodified_since(v i64) {
	if !isnil(o.h) { C.opendal_read_options_set_if_unmodified_since(o.h, v) }
}

pub fn (o &ReadOptions) set_concurrent(v usize) {
	if !isnil(o.h) { C.opendal_read_options_set_concurrent(o.h, v) }
}

pub fn (o &ReadOptions) set_chunk(v usize) {
	if !isnil(o.h) { C.opendal_read_options_set_chunk(o.h, v) }
}

pub fn (o &ReadOptions) set_gap(v usize) {
	if !isnil(o.h) { C.opendal_read_options_set_gap(o.h, v) }
}

pub fn (o &ReadOptions) set_content_length_hint(v u64) {
	if !isnil(o.h) { C.opendal_read_options_set_content_length_hint(o.h, v) }
}

pub fn (o &ReadOptions) set_override_content_type(v string) {
	if !isnil(o.h) { C.opendal_read_options_set_override_content_type(o.h, v.str) }
}

pub fn (o &ReadOptions) set_override_cache_control(v string) {
	if !isnil(o.h) { C.opendal_read_options_set_override_cache_control(o.h, v.str) }
}

pub fn (o &ReadOptions) set_override_content_disposition(v string) {
	if !isnil(o.h) { C.opendal_read_options_set_override_content_disposition(o.h, v.str) }
}

pub struct ReaderOptions {
mut:
	h &C.opendal_reader_options = unsafe { nil }
}

pub fn (o &ReaderOptions) init() ! {
	o.h = C.opendal_reader_options_new()
	if isnil(o.h) { return error('reader_options_new failed') }
}

pub fn (o &ReaderOptions) free() {
	if !isnil(o.h) { C.opendal_reader_options_free(o.h); o.h = unsafe { nil } }
}

pub fn (o &ReaderOptions) set_version(v string) {
	if !isnil(o.h) { C.opendal_reader_options_set_version(o.h, v.str) }
}

pub fn (o &ReaderOptions) set_if_match(v string) {
	if !isnil(o.h) { C.opendal_reader_options_set_if_match(o.h, v.str) }
}

pub fn (o &ReaderOptions) set_if_none_match(v string) {
	if !isnil(o.h) { C.opendal_reader_options_set_if_none_match(o.h, v.str) }
}

pub fn (o &ReaderOptions) set_if_modified_since(v i64) {
	if !isnil(o.h) { C.opendal_reader_options_set_if_modified_since(o.h, v) }
}

pub fn (o &ReaderOptions) set_if_unmodified_since(v i64) {
	if !isnil(o.h) { C.opendal_reader_options_set_if_unmodified_since(o.h, v) }
}

pub fn (o &ReaderOptions) set_content_length_hint(v u64) {
	if !isnil(o.h) { C.opendal_reader_options_set_content_length_hint(o.h, v) }
}

pub fn (o &ReaderOptions) set_concurrent(v usize) {
	if !isnil(o.h) { C.opendal_reader_options_set_concurrent(o.h, v) }
}

pub fn (o &ReaderOptions) set_chunk(v usize) {
	if !isnil(o.h) { C.opendal_reader_options_set_chunk(o.h, v) }
}

pub fn (o &ReaderOptions) set_gap(v usize) {
	if !isnil(o.h) { C.opendal_reader_options_set_gap(o.h, v) }
}

pub fn (o &ReaderOptions) set_prefetch(v usize) {
	if !isnil(o.h) { C.opendal_reader_options_set_prefetch(o.h, v) }
}

pub struct StatOptions {
mut:
	h &C.opendal_stat_options = unsafe { nil }
}

pub fn (o &StatOptions) init() ! {
	o.h = C.opendal_stat_options_new()
	if isnil(o.h) { return error('stat_options_new failed') }
}

pub fn (o &StatOptions) free() {
	if !isnil(o.h) { C.opendal_stat_options_free(o.h); o.h = unsafe { nil } }
}

pub fn (o &StatOptions) set_version(v string) {
	if !isnil(o.h) { C.opendal_stat_options_set_version(o.h, v.str) }
}

pub fn (o &StatOptions) set_if_match(v string) {
	if !isnil(o.h) { C.opendal_stat_options_set_if_match(o.h, v.str) }
}

pub fn (o &StatOptions) set_if_none_match(v string) {
	if !isnil(o.h) { C.opendal_stat_options_set_if_none_match(o.h, v.str) }
}

pub fn (o &StatOptions) set_if_modified_since(v i64) {
	if !isnil(o.h) { C.opendal_stat_options_set_if_modified_since(o.h, v) }
}

pub fn (o &StatOptions) set_if_unmodified_since(v i64) {
	if !isnil(o.h) { C.opendal_stat_options_set_if_unmodified_since(o.h, v) }
}

pub fn (o &StatOptions) set_override_content_type(v string) {
	if !isnil(o.h) { C.opendal_stat_options_set_override_content_type(o.h, v.str) }
}

pub fn (o &StatOptions) set_override_cache_control(v string) {
	if !isnil(o.h) { C.opendal_stat_options_set_override_cache_control(o.h, v.str) }
}

pub fn (o &StatOptions) set_override_content_disposition(v string) {
	if !isnil(o.h) { C.opendal_stat_options_set_override_content_disposition(o.h, v.str) }
}

pub struct ListOptions {
mut:
	h &C.opendal_list_options = unsafe { nil }
}

pub fn (o &ListOptions) init() ! {
	o.h = C.opendal_list_options_new()
	if isnil(o.h) { return error('list_options_new failed') }
}

pub fn (o &ListOptions) free() {
	if !isnil(o.h) { C.opendal_list_options_free(o.h); o.h = unsafe { nil } }
}

pub fn (o &ListOptions) set_recursive(v bool) {
	if !isnil(o.h) { C.opendal_list_options_set_recursive(o.h, v) }
}

pub fn (o &ListOptions) set_limit(v usize) {
	if !isnil(o.h) { C.opendal_list_options_set_limit(o.h, v) }
}

pub fn (o &ListOptions) set_start_after(v string) {
	if !isnil(o.h) { C.opendal_list_options_set_start_after(o.h, v.str) }
}

pub fn (o &ListOptions) set_versions(v bool) {
	if !isnil(o.h) { C.opendal_list_options_set_versions(o.h, v) }
}

pub fn (o &ListOptions) set_deleted(v bool) {
	if !isnil(o.h) { C.opendal_list_options_set_deleted(o.h, v) }
}

pub struct DeleteOptions {
mut:
	h &C.opendal_delete_options = unsafe { nil }
}

pub fn (o &DeleteOptions) init() ! {
	o.h = C.opendal_delete_options_new()
	if isnil(o.h) { return error('delete_options_new failed') }
}

pub fn (o &DeleteOptions) free() {
	if !isnil(o.h) { C.opendal_delete_options_free(o.h); o.h = unsafe { nil } }
}

pub fn (o &DeleteOptions) set_version(v string) {
	if !isnil(o.h) { C.opendal_delete_options_set_version(o.h, v.str) }
}

pub fn (o &DeleteOptions) set_recursive(v bool) {
	if !isnil(o.h) { C.opendal_delete_options_set_recursive(o.h, v) }
}

pub struct CopyOptions {
mut:
	h &C.opendal_copy_options = unsafe { nil }
}

pub fn (o &CopyOptions) init() ! {
	o.h = C.opendal_copy_options_new()
	if isnil(o.h) { return error('copy_options_new failed') }
}

pub fn (o &CopyOptions) free() {
	if !isnil(o.h) { C.opendal_copy_options_free(o.h); o.h = unsafe { nil } }
}

pub fn (o &CopyOptions) set_if_not_exists(v bool) {
	if !isnil(o.h) { C.opendal_copy_options_set_if_not_exists(o.h, v) }
}

pub fn (o &CopyOptions) set_if_match(v string) {
	if !isnil(o.h) { C.opendal_copy_options_set_if_match(o.h, v.str) }
}

pub fn (o &CopyOptions) set_source_version(v string) {
	if !isnil(o.h) { C.opendal_copy_options_set_source_version(o.h, v.str) }
}

pub fn (o &CopyOptions) set_source_content_length_hint(v u64) {
	if !isnil(o.h) { C.opendal_copy_options_set_source_content_length_hint(o.h, v) }
}

pub fn (o &CopyOptions) set_concurrent(v usize) {
	if !isnil(o.h) { C.opendal_copy_options_set_concurrent(o.h, v) }
}

pub fn (o &CopyOptions) set_chunk(v usize) {
	if !isnil(o.h) { C.opendal_copy_options_set_chunk(o.h, v) }
}

// ---------- Operator ----------
pub struct Operator {
mut:
	h &C.opendal_operator = unsafe { nil }
}

pub fn (o &Operator) valid() bool {
	return !isnil(o.h)
}

pub fn Operator.new(scheme string, opts ?map[string]string, layers ?Layers) !Operator {
	mut oo := OperatorOptions{}
	oo.init() or { return err }
	defer { oo.free() }
	if m := opts {
		for k, v in m { oo.set(k, v) }
	}
	r := if l := layers {
		C.opendal_operator_new_with_layers(scheme.str, oo.h, l.h)
	} else {
		C.opendal_operator_new(scheme.str, oo.h)
	}
	ok_or_error(r.error) or { return err }
	if isnil(r.op) { return error('operator_new: null operator') }
	return Operator{ h: r.op }
}

pub fn (o &Operator) free() {
	if !isnil(o.h) { C.opendal_operator_free(o.h); o.h = unsafe { nil } }
}

pub fn (o &Operator) write(path string, data []u8, opts ?WriteOptions) ! {
	b := cbytes(data)
	e := if x := opts { C.opendal_operator_write_with(o.h, path.str, &b, x.h) } else { C.opendal_operator_write(o.h, path.str, &b) }
	ok_or_error(e) or { return err }
}

pub fn (o &Operator) write_with_metadata(path string, data []u8, opts ?WriteOptions) !Metadata {
	b := cbytes(data)
	return meta_result(C.opendal_operator_write_with_metadata(o.h, path.str, &b, wopt(opts)))
}

pub fn (o &Operator) read(path string, opts ?ReadOptions) ![]u8 {
	r := if x := opts { C.opendal_operator_read_with(o.h, path.str, x.h) } else { C.opendal_operator_read(o.h, path.str) }
	return read_result(r)
}

pub fn (o &Operator) reader(path string, opts ?ReaderOptions) !Reader {
	r := if x := opts { C.opendal_operator_reader_with(o.h, path.str, x.h) } else { C.opendal_operator_reader(o.h, path.str) }
	return reader_result(r)
}

pub fn (o &Operator) writer(path string, opts ?WriteOptions) !Writer {
	r := if x := opts { C.opendal_operator_writer_with(o.h, path.str, x.h) } else { C.opendal_operator_writer(o.h, path.str) }
	return writer_result(r)
}

pub fn (o &Operator) delete(path string, opts ?DeleteOptions) ! {
	e := if x := opts { C.opendal_operator_delete_with(o.h, path.str, x.h) } else { C.opendal_operator_delete(o.h, path.str) }
	ok_or_error(e) or { return err }
}

pub fn (o &Operator) is_exist(path string) !bool {
	r := C.opendal_operator_is_exist(o.h, path.str)
	ok_or_error(r.error) or { return err }
	return r.is_exist
}

pub fn (o &Operator) exists(path string) !bool {
	r := C.opendal_operator_exists(o.h, path.str)
	ok_or_error(r.error) or { return err }
	return r.exists
}

pub fn (o &Operator) stat(path string, opts ?StatOptions) !Metadata {
	r := if x := opts { C.opendal_operator_stat_with(o.h, path.str, x.h) } else { C.opendal_operator_stat(o.h, path.str) }
	return stat_result(r)
}

pub fn (o &Operator) list(path string, opts ?ListOptions) !Lister {
	r := if x := opts { C.opendal_operator_list_with(o.h, path.str, x.h) } else { C.opendal_operator_list(o.h, path.str) }
	return list_result(r)
}

pub fn (o &Operator) create_dir(path string) ! {
	ok_or_error(C.opendal_operator_create_dir(o.h, path.str)) or { return err }
}

pub fn (o &Operator) rename(src string, dest string) ! {
	ok_or_error(C.opendal_operator_rename(o.h, src.str, dest.str)) or { return err }
}

pub fn (o &Operator) copy(src string, dest string, opts ?CopyOptions) ! {
	e := if x := opts { C.opendal_operator_copy_with(o.h, src.str, dest.str, x.h) } else { C.opendal_operator_copy(o.h, src.str, dest.str) }
	ok_or_error(e) or { return err }
}

pub fn (o &Operator) check() ! {
	ok_or_error(C.opendal_operator_check(o.h)) or { return err }
}

pub fn (o &Operator) copier(src string, dest string, opts ?CopyOptions) !Copier {
	r := if x := opts { C.opendal_operator_copier_with(o.h, src.str, dest.str, x.h) } else { C.opendal_operator_copier(o.h, src.str, dest.str) }
	return copier_result(r)
}

pub fn (o &Operator) info() !OperatorInfo {
	h := C.opendal_operator_info_new(o.h)
	if isnil(h) { return error('operator_info_new failed') }
	return OperatorInfo{ h: h }
}

pub fn (o &Operator) presign_read(path string, expire_secs u64, opts ?ReadOptions) !PresignedRequest {
	r := if x := opts { C.opendal_operator_presign_read_with(o.h, path.str, expire_secs, x.h) } else { C.opendal_operator_presign_read(o.h, path.str, expire_secs) }
	return presign_result(r)
}

pub fn (o &Operator) presign_write(path string, expire_secs u64, opts ?WriteOptions) !PresignedRequest {
	r := if x := opts { C.opendal_operator_presign_write_with(o.h, path.str, expire_secs, x.h) } else { C.opendal_operator_presign_write(o.h, path.str, expire_secs) }
	return presign_result(r)
}

pub fn (o &Operator) presign_delete(path string, expire_secs u64, opts ?DeleteOptions) !PresignedRequest {
	r := if x := opts { C.opendal_operator_presign_delete_with(o.h, path.str, expire_secs, x.h) } else { C.opendal_operator_presign_delete(o.h, path.str, expire_secs) }
	return presign_result(r)
}

pub fn (o &Operator) presign_stat(path string, expire_secs u64, opts ?StatOptions) !PresignedRequest {
	r := if x := opts { C.opendal_operator_presign_stat_with(o.h, path.str, expire_secs, x.h) } else { C.opendal_operator_presign_stat(o.h, path.str, expire_secs) }
	return presign_result(r)
}

// ---------- Metadata ----------
pub struct Metadata {
mut:
	h &C.opendal_metadata = unsafe { nil }
}

pub fn (m &Metadata) free() {
	if !isnil(m.h) { C.opendal_metadata_free(m.h); m.h = unsafe { nil } }
}

pub fn (m &Metadata) mode() u8 { return C.opendal_metadata_mode(m.h) }
pub fn (m &Metadata) content_length() u64 { return C.opendal_metadata_content_length(m.h) }
pub fn (m &Metadata) is_file() bool { return C.opendal_metadata_is_file(m.h) }
pub fn (m &Metadata) is_dir() bool { return C.opendal_metadata_is_dir(m.h) }
pub fn (m &Metadata) is_current() u8 { return C.opendal_metadata_is_current(m.h) }
pub fn (m &Metadata) is_deleted() bool { return C.opendal_metadata_is_deleted(m.h) }
pub fn (m &Metadata) cache_control() string { return take_string(C.opendal_metadata_cache_control(m.h)) }
pub fn (m &Metadata) content_disposition() string { return take_string(C.opendal_metadata_content_disposition(m.h)) }
pub fn (m &Metadata) content_md5() string { return take_string(C.opendal_metadata_content_md5(m.h)) }
pub fn (m &Metadata) content_type() string { return take_string(C.opendal_metadata_content_type(m.h)) }
pub fn (m &Metadata) content_encoding() string { return take_string(C.opendal_metadata_content_encoding(m.h)) }
pub fn (m &Metadata) etag() string { return take_string(C.opendal_metadata_etag(m.h)) }
pub fn (m &Metadata) version() string { return take_string(C.opendal_metadata_version(m.h)) }
pub fn (m &Metadata) last_modified_ms() i64 { return C.opendal_metadata_last_modified_ms(m.h) }

pub fn (m &Metadata) user_metadata() !map[string]string {
	um := C.opendal_metadata_get_user_metadata(m.h)
	if isnil(um) { return error('user_metadata unavailable') }
	defer { C.opendal_metadata_user_metadata_free(um) }
	n := int(C.opendal_metadata_user_metadata_len(um))
	p := C.opendal_metadata_user_metadata_pairs(um)
	mut out := map[string]string{}
	for i in 0 .. n { out[borrow_string(p[i].key)] = borrow_string(p[i].value) }
	return out
}

// ---------- Entry / Lister ----------
pub struct Entry {
mut:
	h &C.opendal_entry = unsafe { nil }
}

pub fn (e &Entry) is_none() bool { return isnil(e.h) }
pub fn (e &Entry) path() string { return take_string(C.opendal_entry_path(e.h)) }
pub fn (e &Entry) name() string { return take_string(C.opendal_entry_name(e.h)) }
pub fn (e &Entry) metadata() Metadata { return Metadata{ h: C.opendal_entry_metadata(e.h) } }
pub fn (e &Entry) free() {
	if !isnil(e.h) { C.opendal_entry_free(e.h); e.h = unsafe { nil } }
}

pub struct Lister {
mut:
	h &C.opendal_lister = unsafe { nil }
}

pub fn (l &Lister) next() !Entry {
	r := C.opendal_lister_next(l.h)
	ok_or_error(r.error) or { return err }
	if isnil(r.entry) { return Entry{} }
	return Entry{ h: r.entry }
}

pub fn (l &Lister) free() {
	if !isnil(l.h) { C.opendal_lister_free(l.h); l.h = unsafe { nil } }
}

// ---------- Reader / Writer / Copier ----------
pub struct Reader {
mut:
	h &C.opendal_reader = unsafe { nil }
}

pub fn (r &Reader) read(len usize) ![]u8 {
	if len == 0 { return []u8{} }
	mut buf := []u8{len: int(len)}
	res := C.opendal_reader_read(r.h, buf.data, len)
	ok_or_error(res.error) or { return err }
	return buf[..int(res.size)]
}

pub fn (r &Reader) seek(offset i64, whence int) !u64 {
	res := C.opendal_reader_seek(r.h, offset, i32(whence))
	ok_or_error(res.error) or { return err }
	return res.pos
}

pub fn (r &Reader) free() {
	if !isnil(r.h) { C.opendal_reader_free(r.h); r.h = unsafe { nil } }
}

pub struct Writer {
mut:
	h &C.opendal_writer = unsafe { nil }
}

pub fn (w &Writer) write(data []u8) !usize {
	b := cbytes(data)
	r := C.opendal_writer_write(w.h, &b)
	ok_or_error(r.error) or { return err }
	return r.size
}

pub fn (w &Writer) close() ! {
	ok_or_error(C.opendal_writer_close(w.h)) or { return err }
}

pub fn (w &Writer) close_with_metadata() !Metadata {
	return meta_result(C.opendal_writer_close_with_metadata(w.h))
}

pub fn (w &Writer) free() {
	if !isnil(w.h) { C.opendal_writer_free(w.h); w.h = unsafe { nil } }
}

pub struct CopierNext {
pub:
	size usize
	has_next bool
}

pub struct Copier {
mut:
	h &C.opendal_copier = unsafe { nil }
}

pub fn (c &Copier) next() !CopierNext {
	r := C.opendal_copier_next(c.h)
	ok_or_error(r.error) or { return err }
	return CopierNext{ size: r.size, has_next: r.has_next }
}

pub fn (c &Copier) abort() ! {
	ok_or_error(C.opendal_copier_abort(c.h)) or { return err }
}

pub fn (c &Copier) free() {
	if !isnil(c.h) { C.opendal_copier_free(c.h); c.h = unsafe { nil } }
}

// ---------- OperatorInfo / Capability ----------
pub struct OperatorInfo {
mut:
	h &C.opendal_operator_info = unsafe { nil }
}

pub fn (i &OperatorInfo) scheme() string { return take_string(C.opendal_operator_info_get_scheme(i.h)) }
pub fn (i &OperatorInfo) root() string { return take_string(C.opendal_operator_info_get_root(i.h)) }
pub fn (i &OperatorInfo) name() string { return take_string(C.opendal_operator_info_get_name(i.h)) }
pub fn (i &OperatorInfo) capability() Capability { return capability_from(C.opendal_operator_info_get_capability(i.h)) }
pub fn (i &OperatorInfo) free() {
	if !isnil(i.h) { C.opendal_operator_info_free(i.h); i.h = unsafe { nil } }
}

pub struct Capability {
pub:
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

fn capability_from(c C.opendal_capability) Capability {
	return Capability{
		stat: c.stat
		stat_with_if_match: c.stat_with_if_match
		stat_with_if_none_match: c.stat_with_if_none_match
		stat_with_if_modified_since: c.stat_with_if_modified_since
		stat_with_if_unmodified_since: c.stat_with_if_unmodified_since
		stat_with_override_cache_control: c.stat_with_override_cache_control
		stat_with_override_content_disposition: c.stat_with_override_content_disposition
		stat_with_override_content_type: c.stat_with_override_content_type
		stat_with_version: c.stat_with_version
		read: c.read
		read_with_if_match: c.read_with_if_match
		read_with_if_none_match: c.read_with_if_none_match
		read_with_override_cache_control: c.read_with_override_cache_control
		read_with_override_content_disposition: c.read_with_override_content_disposition
		read_with_override_content_type: c.read_with_override_content_type
		read_with_if_modified_since: c.read_with_if_modified_since
		read_with_if_unmodified_since: c.read_with_if_unmodified_since
		read_with_version: c.read_with_version
		write: c.write
		write_can_multi: c.write_can_multi
		write_can_empty: c.write_can_empty
		write_can_append: c.write_can_append
		write_with_content_type: c.write_with_content_type
		write_with_content_disposition: c.write_with_content_disposition
		write_with_content_encoding: c.write_with_content_encoding
		write_with_cache_control: c.write_with_cache_control
		write_with_if_match: c.write_with_if_match
		write_with_if_none_match: c.write_with_if_none_match
		write_with_if_not_exists: c.write_with_if_not_exists
		write_with_user_metadata: c.write_with_user_metadata
		write_multi_max_size: c.write_multi_max_size
		write_multi_min_size: c.write_multi_min_size
		write_total_max_size: c.write_total_max_size
		create_dir: c.create_dir
		delete_: c.delete_
		delete_with_version: c.delete_with_version
		delete_with_recursive: c.delete_with_recursive
		copy: c.copy
		copy_with_if_not_exists: c.copy_with_if_not_exists
		copy_with_if_match: c.copy_with_if_match
		copy_with_source_version: c.copy_with_source_version
		copy_can_multi: c.copy_can_multi
		copy_multi_max_size: c.copy_multi_max_size
		copy_multi_min_size: c.copy_multi_min_size
		rename: c.rename
		list: c.list
		list_with_limit: c.list_with_limit
		list_with_start_after: c.list_with_start_after
		list_with_recursive: c.list_with_recursive
		list_with_versions: c.list_with_versions
		list_with_deleted: c.list_with_deleted
		presign: c.presign
		presign_read: c.presign_read
		presign_stat: c.presign_stat
		presign_write: c.presign_write
		presign_delete: c.presign_delete
		shared: c.shared
	}
}

// ---------- PresignedRequest ----------
pub struct HeaderPair {
pub:
	key string
	value string
}

pub struct PresignedRequest {
mut:
	h &C.opendal_presigned_request = unsafe { nil }
}

pub fn (r &PresignedRequest) method() string { return borrow_string(C.opendal_presigned_request_method(r.h)) }
pub fn (r &PresignedRequest) uri() string { return borrow_string(C.opendal_presigned_request_uri(r.h)) }

pub fn (r &PresignedRequest) headers() []HeaderPair {
	n := int(C.opendal_presigned_request_headers_len(r.h))
	p := C.opendal_presigned_request_headers(r.h)
	mut out := []HeaderPair{len: n}
	for i in 0 .. n {
		out[i] = HeaderPair{ key: borrow_string(p[i].key), value: borrow_string(p[i].value) }
	}
	return out
}

pub fn (r &PresignedRequest) free() {
	if !isnil(r.h) { C.opendal_presigned_request_free(r.h); r.h = unsafe { nil } }
}
