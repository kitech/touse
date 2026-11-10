module clang

fn C.clang_Cursor_getGCCAssemblyTemplate(cursor Cursor) String
pub fn cursor_get_gcc_assembly_template(cursor Cursor) string {
	return cxstring_to_string(C.clang_Cursor_getGCCAssemblyTemplate(cursor))
}

fn C.clang_Cursor_isGCCAssemblyHasGoto(cursor Cursor) u32
pub fn cursor_is_gcc_assembly_has_goto(cursor Cursor) bool {
	return C.clang_Cursor_isGCCAssemblyHasGoto(cursor) != 0
}

fn C.clang_Cursor_getGCCAssemblyNumOutputs(cursor Cursor) u32
pub fn cursor_get_gcc_assembly_num_outputs(cursor Cursor) u32 {
	return C.clang_Cursor_getGCCAssemblyNumOutputs(cursor)
}

fn C.clang_Cursor_getGCCAssemblyNumInputs(cursor Cursor) u32
pub fn cursor_get_gcc_assembly_num_inputs(cursor Cursor) u32 {
	return C.clang_Cursor_getGCCAssemblyNumInputs(cursor)
}

fn C.clang_Cursor_getGCCAssemblyNumClobbers(cursor Cursor) u32
pub fn cursor_get_gcc_assembly_num_clobbers(cursor Cursor) u32 {
	return C.clang_Cursor_getGCCAssemblyNumClobbers(cursor)
}

fn C.clang_Cursor_getGCCAssemblyClobber(cursor Cursor, i u32) String
pub fn cursor_get_gcc_assembly_clobber(cursor Cursor, i u32) string {
	return cxstring_to_string(C.clang_Cursor_getGCCAssemblyClobber(cursor, i))
}

fn C.clang_Cursor_isGCCAssemblyVolatile(cursor Cursor) u32
pub fn cursor_is_gcc_assembly_volatile(cursor Cursor) bool {
	return C.clang_Cursor_isGCCAssemblyVolatile(cursor) != 0
}
