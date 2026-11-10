module clang

// ============================================================================
// 错误码（与 C 侧 CXErrorCode 严格对齐）
// ============================================================================
pub enum ErrorCode {
	success           = 0
	failure           = 1
	crashed           = 2
	invalid_arguments = 3
	ast_read_error    = 4
}

// ============================================================================
// 基础 Index / TranslationUnit
// ============================================================================
fn C.clang_createIndex(excludeDeclarationsFromPCH int, displayDiagnostics int) Index
pub fn create_index(exclude_declarations_from_pch int, display_diagnostics int) Index {
	return C.clang_createIndex(exclude_declarations_from_pch, display_diagnostics)
}

fn C.clang_disposeIndex(index Index)
pub fn dispose_index(index Index) {
	C.clang_disposeIndex(index)
}

fn C.clang_disposeTranslationUnit(tu TranslationUnit)
pub fn dispose_translation_unit(tu TranslationUnit) {
	C.clang_disposeTranslationUnit(tu)
}

// ============================================================================
// parse_translation_unit（基础版，失败只返回 NULL）
// ============================================================================
fn C.clang_parseTranslationUnit(
	idx Index,
	source_filename &char,
	command_line_args &&char,
	num_command_line_args int,
	unsaved_files &C.CXUnsavedFile,
	num_unsaved_files u32,
	options u32,
) TranslationUnit

pub fn parse_translation_unit(
	idx Index,
	source_filename string,
	args []string,
	unsaved_files []UnsavedFile,
	options u32,
) TranslationUnit {
	mut cargs := []&char{cap: args.len}
	for a in args {
		unsafe { cargs << a.str }
	}
	cargs_ptr := unsafe { &&char(cargs.data) }

	mut unsaved_ptr := unsafe { &C.CXUnsavedFile(nil) }
	if unsaved_files.len > 0 {
		unsaved_ptr = unsafe { &C.CXUnsavedFile(unsaved_files.data) }
	}

	return C.clang_parseTranslationUnit(
		idx,
		unsafe { source_filename.str },
		cargs_ptr,
		args.len,
		unsaved_ptr,
		u32(unsaved_files.len),
		options,
	)
}

// ============================================================================
// parse_translation_unit2（可获取错误码 + 诊断）
// ============================================================================
fn C.clang_parseTranslationUnit2(
	idx Index,
	source_filename &char,
	command_line_args &&char,
	num_command_line_args int,
	unsaved_files &C.CXUnsavedFile,
	num_unsaved_files u32,
	options u32,
	out_tu &TranslationUnit,
) int

pub fn parse_translation_unit2(
	idx Index,
	source_filename string,
	args []string,
	unsaved_files []UnsavedFile,
	options u32,
) (TranslationUnit, ErrorCode) {
	mut cargs := []&char{cap: args.len}
	for a in args {
		unsafe { cargs << a.str }
	}
	cargs_ptr := unsafe { &&char(cargs.data) }

	mut unsaved_ptr := unsafe { &C.CXUnsavedFile(nil) }
	if unsaved_files.len > 0 {
		unsaved_ptr = unsafe { &C.CXUnsavedFile(unsaved_files.data) }
	}

	mut out_tu := TranslationUnit(0)
	code := C.clang_parseTranslationUnit2(
		idx,
		unsafe { source_filename.str },
		cargs_ptr,
		args.len,
		unsaved_ptr,
		u32(unsaved_files.len),
		options,
		&out_tu,
	)
	// C 返回 int，映射到枚举
	return out_tu, unsafe { ErrorCode(code) }
}
