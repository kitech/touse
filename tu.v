module clang

fn C.clang_createIndex(excludeDeclarationsFromPCH int, displayDiagnostics int) Index
pub fn create_index(exclude_declarations_from_pch int, display_diagnostics int) Index {
	return C.clang_createIndex(exclude_declarations_from_pch, display_diagnostics)
}

fn C.clang_disposeIndex(index Index)
pub fn dispose_index(index Index) {
	C.clang_disposeIndex(index)
}

fn C.clang_parseTranslationUnit(idx Index, source_filename &char, command_line_args &&char, num_command_line_args int, unsaved_files &C.CXUnsavedFile, num_unsaved_files u32, options u32) TranslationUnit
pub fn parse_translation_unit(idx Index, source_filename string, args []string, unsaved_files []UnsavedFile, options u32) TranslationUnit {
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

fn C.clang_disposeTranslationUnit(tu TranslationUnit)
pub fn dispose_translation_unit(tu TranslationUnit) {
	C.clang_disposeTranslationUnit(tu)
}

fn C.clang_getTranslationUnitTargetInfo(tu TranslationUnit) TargetInfo
pub fn get_translation_unit_target_info(tu TranslationUnit) TargetInfo {
	return C.clang_getTranslationUnitTargetInfo(tu)
}

fn C.clang_TargetInfo_dispose(info TargetInfo)
pub fn target_info_dispose(info TargetInfo) {
	C.clang_TargetInfo_dispose(info)
}

fn C.clang_TargetInfo_getTriple(info TargetInfo) String
pub fn target_info_get_triple(info TargetInfo) string {
	return cxstring_to_string(C.clang_TargetInfo_getTriple(info))
}
