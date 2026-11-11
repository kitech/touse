module clang

fn C.clang_getCursorKindSpelling(kind CursorKind) String
pub fn get_cursor_kind_spelling(kind CursorKind) string {
	return cxstring_to_string(C.clang_getCursorKindSpelling(kind))
}

fn C.clang_executeOnThread(fn_ voidptr, user_data voidptr, stack_size u32)
pub fn execute_on_thread(fn_ voidptr, user_data voidptr, stack_size u32) {
	C.clang_executeOnThread(fn_, user_data, stack_size)
}

// clang/debug.v 追加

fn C.clang_getDefinitionSpellingAndExtent(
	cursor Cursor,
	start_buf &char,
	end_buf &char,
	start_line &u32,
	start_column &u32,
	end_line &u32,
	end_column &u32,
)
pub fn get_definition_spelling_and_extent(cursor Cursor) (string, string, u32, u32, u32, u32) {
	mut start_buf := &char(nil)
	mut end_buf := &char(nil)
	mut start_line := u32(0)
	mut start_col := u32(0)
	mut end_line := u32(0)
	mut end_col := u32(0)
	C.clang_getDefinitionSpellingAndExtent(cursor, &start_buf, &end_buf, &start_line, &start_col,
		&end_line, &end_col)
	return unsafe { start_buf.vstring() }, unsafe { end_buf.vstring() }, start_line, start_col,
		end_line, end_col
}

fn C.clang_enableStackTraces()
pub fn enable_stack_traces() {
	C.clang_enableStackTraces()
}

fn C.clang_install_aborting_llvm_fatal_error_handler()
pub fn install_aborting_llvm_fatal_error_handler() {
	if has_major(16) {
		C.clang_install_aborting_llvm_fatal_error_handler()
	}
}

fn C.clang_uninstall_llvm_fatal_error_handler()
pub fn uninstall_llvm_fatal_error_handler() {
	if has_major(16) {
		C.clang_uninstall_llvm_fatal_error_handler()
	}
}
