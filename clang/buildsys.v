module clang

// ═══ 生成器产出（确认后合入仓库）═══

fn C.clang_ModuleCache_prune(path &char, prune_interval i64, prune_after i64)
pub fn module_cache_prune(path &char, prune_interval i64, prune_after i64) {
	if has_major(16) {
		C.clang_ModuleCache_prune(path, prune_interval, prune_after)
	}
}

fn C.clang_ModuleCache_pruneWithCallback(path &char, prune_interval i64, prune_after i64, callback voidptr, user_data voidptr)
pub fn module_cache_prune_with_callback(path &char, prune_interval i64, prune_after i64, callback voidptr, user_data voidptr) {
	if has_major(16) {
		C.clang_ModuleCache_pruneWithCallback(path, prune_interval, prune_after, callback, user_data)
	}
}

fn C.clang_ModuleMapDescriptor_create(options u32) ModuleMapDescriptor
pub fn module_map_descriptor_create(options u32) ModuleMapDescriptor {
	if has_major(16) {
		return C.clang_ModuleMapDescriptor_create(options)
	}

	return 0
}

fn C.clang_ModuleMapDescriptor_dispose(arg0 ModuleMapDescriptor)
pub fn module_map_descriptor_dispose(arg0 ModuleMapDescriptor) {
	if has_major(16) {
		C.clang_ModuleMapDescriptor_dispose(arg0)
	}
}

fn C.clang_ModuleMapDescriptor_setFrameworkModuleName(arg0 ModuleMapDescriptor, name &char) int
pub fn module_map_descriptor_set_framework_module_name(arg0 ModuleMapDescriptor, name &char) int {
	if has_major(16) {
		return C.clang_ModuleMapDescriptor_setFrameworkModuleName(arg0, name)
	}

	return 0
}

fn C.clang_ModuleMapDescriptor_setUmbrellaHeader(arg0 ModuleMapDescriptor, name &char) int
pub fn module_map_descriptor_set_umbrella_header(arg0 ModuleMapDescriptor, name &char) int {
	if has_major(16) {
		return C.clang_ModuleMapDescriptor_setUmbrellaHeader(arg0, name)
	}

	return 0
}

fn C.clang_ModuleMapDescriptor_writeToBuffer(arg0 ModuleMapDescriptor, options u32, out_buffer_ptr &char, out_buffer_size &u32) int
pub fn module_map_descriptor_write_to_buffer(arg0 ModuleMapDescriptor, options u32, out_buffer_ptr &char, out_buffer_size &u32) int {
	if has_major(16) {
		return C.clang_ModuleMapDescriptor_writeToBuffer(arg0, options, out_buffer_ptr, out_buffer_size)
	}

	return 0
}

fn C.clang_VirtualFileOverlay_addFileMapping(arg0 VirtualFileOverlay, virtualPath_ &char, realPath_ &char) int
pub fn virtual_file_overlay_add_file_mapping(arg0 VirtualFileOverlay, virtualPath_ &char, realPath_ &char) int {
	if has_major(16) {
		return C.clang_VirtualFileOverlay_addFileMapping(arg0, virtualPath_, realPath_)
	}

	return 0
}

fn C.clang_VirtualFileOverlay_create(options u32) VirtualFileOverlay
pub fn virtual_file_overlay_create(options u32) VirtualFileOverlay {
	if has_major(16) {
		return C.clang_VirtualFileOverlay_create(options)
	}

	return 0
}

fn C.clang_VirtualFileOverlay_dispose(arg0 VirtualFileOverlay)
pub fn virtual_file_overlay_dispose(arg0 VirtualFileOverlay) {
	if has_major(16) {
		C.clang_VirtualFileOverlay_dispose(arg0)
	}
}

fn C.clang_VirtualFileOverlay_setCaseSensitivity(arg0 VirtualFileOverlay, caseSensitive_ int) int
pub fn virtual_file_overlay_set_case_sensitivity(arg0 VirtualFileOverlay, caseSensitive_ int) int {
	if has_major(16) {
		return C.clang_VirtualFileOverlay_setCaseSensitivity(arg0, caseSensitive_)
	}

	return 0
}

fn C.clang_VirtualFileOverlay_writeToBuffer(arg0 VirtualFileOverlay, options u32, out_buffer_ptr &char, out_buffer_size &u32) int
pub fn virtual_file_overlay_write_to_buffer(arg0 VirtualFileOverlay, options u32, out_buffer_ptr &char, out_buffer_size &u32) int {
	if has_major(16) {
		return C.clang_VirtualFileOverlay_writeToBuffer(arg0, options, out_buffer_ptr, out_buffer_size)
	}

	return 0
}

fn C.clang_free(buffer voidptr)
pub fn mem_free(buffer voidptr) {
	if has_major(16) {
		C.clang_free(buffer)
	}
}

fn C.clang_getBuildSessionTimestamp() u64
pub fn get_build_session_timestamp() u64 {
	if has_major(16) {
		return C.clang_getBuildSessionTimestamp()
	}

	return 0
}
