module clang

fn C.clang_codeCompleteAt(tu TranslationUnit, complete_filename &char, complete_line u32, complete_column u32, unsaved_files &C.CXUnsavedFile, num_unsaved_files u32, options u32) &C.CXCodeCompleteResults
pub fn code_complete_at(tu TranslationUnit, filename string, line u32, column u32, options u32) &CodeCompleteResultsStruct {
	return C.clang_codeCompleteAt(tu, unsafe { filename.str }, line, column, unsafe { &C.CXUnsavedFile(nil) }, 0, options)
}

fn C.clang_disposeCodeCompleteResults(results &C.CXCodeCompleteResults)
pub fn dispose_code_complete_results(results &CodeCompleteResultsStruct) {
	C.clang_disposeCodeCompleteResults(results)
}

fn C.clang_codeCompleteGetNumDiagnostics(results &C.CXCodeCompleteResults) u32
pub fn code_complete_get_num_diagnostics(results &CodeCompleteResultsStruct) u32 {
	return C.clang_codeCompleteGetNumDiagnostics(results)
}

fn C.clang_codeCompleteGetDiagnostic(results &C.CXCodeCompleteResults, index u32) Diagnostic
pub fn code_complete_get_diagnostic(results &CodeCompleteResultsStruct, index u32) Diagnostic {
	return C.clang_codeCompleteGetDiagnostic(results, index)
}

fn C.clang_codeCompleteGetContexts(results &C.CXCodeCompleteResults) u64
pub fn code_complete_get_contexts(results &CodeCompleteResultsStruct) u64 {
	return C.clang_codeCompleteGetContexts(results)
}

fn C.clang_getNumCompletionChunks(cs CompletionString) u32
pub fn get_completion_string_num_chunks(cs CompletionString) u32 {
	return C.clang_getNumCompletionChunks(cs)
}

fn C.clang_getCompletionChunkKind(cs CompletionString, chunk_number u32) u32
pub fn get_completion_chunk_kind(cs CompletionString, chunk_number u32) u32 {
	return C.clang_getCompletionChunkKind(cs, chunk_number)
}

fn C.clang_getCompletionChunkText(cs CompletionString, chunk_number u32) String
pub fn get_completion_chunk_text(cs CompletionString, chunk_number u32) string {
	return cxstring_to_string(C.clang_getCompletionChunkText(cs, chunk_number))
}

fn C.clang_getCompletionChunkCompletionString(cs CompletionString, chunk_number u32) CompletionString
pub fn get_completion_chunk_completion_string(cs CompletionString, chunk_number u32) CompletionString {
	return C.clang_getCompletionChunkCompletionString(cs, chunk_number)
}

fn C.clang_getCompletionParent(cs CompletionString, kind &CursorKind) String
pub fn get_completion_parent(cs CompletionString) (string, CursorKind) {
	mut kind := CursorKind.invalid
	s := cxstring_to_string(C.clang_getCompletionParent(cs, &kind))
	return s, kind
}

fn C.clang_getCompletionBriefComment(cs CompletionString) String
pub fn get_completion_brief_comment(cs CompletionString) string {
	return cxstring_to_string(C.clang_getCompletionBriefComment(cs))
}
