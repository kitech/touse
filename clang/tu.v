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

fn C.clang_CXIndex_getGlobalOptions(arg0 Index) u32
pub fn cx_index_get_global_options(arg0 Index) u32 {
	return C.clang_CXIndex_getGlobalOptions(arg0)
}

fn C.clang_CXIndex_setGlobalOptions(arg0 Index, options u32)
pub fn cx_index_set_global_options(arg0 Index, options u32) {
	C.clang_CXIndex_setGlobalOptions(arg0, options)
}

fn C.clang_CXIndex_setInvocationEmissionPathOption(arg0 Index, path &char)
pub fn cx_index_set_invocation_emission_path_option(arg0 Index, path &char) {
	C.clang_CXIndex_setInvocationEmissionPathOption(arg0, path)
}

fn C.clang_IndexAction_create(c_idx Index) IndexAction
pub fn index_action_create(c_idx Index) IndexAction {
	return C.clang_IndexAction_create(c_idx)
}

fn C.clang_IndexAction_dispose(arg0 IndexAction)
pub fn index_action_dispose(arg0 IndexAction) {
	C.clang_IndexAction_dispose(arg0)
}

fn C.clang_Module_getFullName(module_ Module) String
pub fn module_get_full_name(module_ Module) string {
	return cxstring_to_string(C.clang_Module_getFullName(module_))
}

fn C.clang_Module_getName(module_ Module) String
pub fn module_get_name(module_ Module) string {
	return cxstring_to_string(C.clang_Module_getName(module_))
}

fn C.clang_Module_getNumTopLevelHeaders(arg0 TranslationUnit, module_ Module) u32
pub fn module_get_num_top_level_headers(arg0 TranslationUnit, module_ Module) u32 {
	return C.clang_Module_getNumTopLevelHeaders(arg0, module_)
}

fn C.clang_Module_getParent(module_ Module) Module
pub fn module_get_parent(module_ Module) Module {
	return C.clang_Module_getParent(module_)
}

fn C.clang_Module_getTopLevelHeader(arg0 TranslationUnit, module_ Module, index u32) File
pub fn module_get_top_level_header(arg0 TranslationUnit, module_ Module, index u32) File {
	return C.clang_Module_getTopLevelHeader(arg0, module_, index)
}

fn C.clang_Module_isSystem(module_ Module) int
pub fn module_is_system(module_ Module) int {
	return C.clang_Module_isSystem(module_)
}

fn C.clang_TargetInfo_dispose(info TargetInfo)
pub fn target_info_dispose(info TargetInfo) {
	C.clang_TargetInfo_dispose(info)
}

fn C.clang_TargetInfo_getPointerWidth(info TargetInfo) int
pub fn target_info_get_pointer_width(info TargetInfo) int {
	return C.clang_TargetInfo_getPointerWidth(info)
}

fn C.clang_TargetInfo_getTriple(info TargetInfo) String
pub fn target_info_get_triple(info TargetInfo) string {
	return cxstring_to_string(C.clang_TargetInfo_getTriple(info))
}

fn C.clang_createIndexWithOptions(options &int) Index
pub fn create_index_with_options(options &int) Index {
	if has_major(17) {
		return C.clang_createIndexWithOptions(options)
	}

	return 0
}

fn C.clang_createTranslationUnit(c_idx Index, ast_filename &char) TranslationUnit
pub fn create_translation_unit(c_idx Index, ast_filename &char) TranslationUnit {
	return C.clang_createTranslationUnit(c_idx, ast_filename)
}

fn C.clang_createTranslationUnit2(c_idx Index, ast_filename &char, out_TU_ &TranslationUnit) int
pub fn create_translation_unit2(c_idx Index, ast_filename &char, out_TU_ &TranslationUnit) int {
	return C.clang_createTranslationUnit2(c_idx, ast_filename, out_TU_)
}

fn C.clang_defaultEditingTranslationUnitOptions() u32
pub fn default_editing_translation_unit_options() u32 {
	return C.clang_defaultEditingTranslationUnitOptions()
}

fn C.clang_defaultReparseOptions(tu TranslationUnit) u32
pub fn default_reparse_options(tu TranslationUnit) u32 {
	return C.clang_defaultReparseOptions(tu)
}

fn C.clang_disposeCXTUResourceUsage(usage TUResourceUsage)
pub fn dispose_cxtu_resource_usage(usage TUResourceUsage) {
	C.clang_disposeCXTUResourceUsage(usage)
}

fn C.clang_getTranslationUnitSpelling(ct_unit TranslationUnit) String
pub fn get_translation_unit_spelling(ct_unit TranslationUnit) string {
	return cxstring_to_string(C.clang_getTranslationUnitSpelling(ct_unit))
}

fn C.clang_getTranslationUnitTargetInfo(ct_unit TranslationUnit) TargetInfo
pub fn get_translation_unit_target_info(ct_unit TranslationUnit) TargetInfo {
	return C.clang_getTranslationUnitTargetInfo(ct_unit)
}

fn C.clang_parseTranslationUnit2FullArgv(c_idx Index, source_filename &char, command_line_args &&voidptr, num_command_line_args int, unsaved_files &UnsavedFile, num_unsaved_files u32, options u32, out_TU_ &TranslationUnit) int
pub fn parse_translation_unit2_full_argv(c_idx Index, source_filename &char, command_line_args &&voidptr, num_command_line_args int, unsaved_files &UnsavedFile, num_unsaved_files u32, options u32, out_TU_ &TranslationUnit) int {
	return C.clang_parseTranslationUnit2FullArgv(c_idx, source_filename, command_line_args, num_command_line_args, unsaved_files, num_unsaved_files, options, out_TU_)
}

fn C.clang_remap_dispose(arg0 Remapping)
pub fn remap_dispose(arg0 Remapping) {
	C.clang_remap_dispose(arg0)
}

fn C.clang_reparseTranslationUnit(tu TranslationUnit, num_unsaved_files u32, unsaved_files &UnsavedFile, options u32) int
pub fn reparse_translation_unit(tu TranslationUnit, num_unsaved_files u32, unsaved_files &UnsavedFile, options u32) int {
	return C.clang_reparseTranslationUnit(tu, num_unsaved_files, unsaved_files, options)
}

fn C.clang_saveTranslationUnit(tu TranslationUnit, file_name &char, options u32) int
pub fn save_translation_unit(tu TranslationUnit, file_name &char, options u32) int {
	return C.clang_saveTranslationUnit(tu, file_name, options)
}

fn C.clang_suspendTranslationUnit(arg0 TranslationUnit) u32
pub fn suspend_translation_unit(arg0 TranslationUnit) u32 {
	return C.clang_suspendTranslationUnit(arg0)
}
