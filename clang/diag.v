module clang

fn C.clang_getNumDiagnostics(tu TranslationUnit) u32
pub fn get_num_diagnostics(tu TranslationUnit) u32 {
	return C.clang_getNumDiagnostics(tu)
}

fn C.clang_getDiagnostic(tu TranslationUnit, index u32) Diagnostic
pub fn get_diagnostic(tu TranslationUnit, index u32) Diagnostic {
	return C.clang_getDiagnostic(tu, index)
}

fn C.clang_disposeDiagnostic(diag Diagnostic)
pub fn dispose_diagnostic(diag Diagnostic) {
	C.clang_disposeDiagnostic(diag)
}

fn C.clang_formatDiagnostic(diag Diagnostic, options u32) String
pub fn format_diagnostic(diag Diagnostic, options u32) string {
	return cxstring_to_string(C.clang_formatDiagnostic(diag, options))
}

fn C.clang_defaultDiagnosticDisplayOptions() u32
pub fn default_diagnostic_display_options() u32 {
	return C.clang_defaultDiagnosticDisplayOptions()
}

fn C.clang_getDiagnosticSeverity(diag Diagnostic) DiagnosticSeverity
pub fn get_diagnostic_severity(diag Diagnostic) DiagnosticSeverity {
	return C.clang_getDiagnosticSeverity(diag)
}

fn C.clang_getDiagnosticSpelling(diag Diagnostic) String
pub fn get_diagnostic_spelling(diag Diagnostic) string {
	return cxstring_to_string(C.clang_getDiagnosticSpelling(diag))
}

fn C.clang_getDiagnosticCategory(diag Diagnostic) u32
pub fn get_diagnostic_category(diag Diagnostic) u32 {
	return C.clang_getDiagnosticCategory(diag)
}

fn C.clang_getDiagnosticCategoryText(diag Diagnostic) String
pub fn get_diagnostic_category_text(diag Diagnostic) string {
	return cxstring_to_string(C.clang_getDiagnosticCategoryText(diag))
}

fn C.clang_getDiagnosticLocation(diag Diagnostic) SourceLocation
pub fn get_diagnostic_location(diag Diagnostic) SourceLocation {
	return C.clang_getDiagnosticLocation(diag)
}

fn C.clang_getDiagnosticNumRanges(diag Diagnostic) u32
pub fn get_diagnostic_num_ranges(diag Diagnostic) u32 {
	return C.clang_getDiagnosticNumRanges(diag)
}

fn C.clang_getDiagnosticRange(diag Diagnostic, range_index u32) SourceRange
pub fn get_diagnostic_range(diag Diagnostic, range_index u32) SourceRange {
	return C.clang_getDiagnosticRange(diag, range_index)
}

fn C.clang_getDiagnosticNumFixIts(diag Diagnostic) u32
pub fn get_diagnostic_num_fix_its(diag Diagnostic) u32 {
	return C.clang_getDiagnosticNumFixIts(diag)
}

fn C.clang_getDiagnosticFixIt(diag Diagnostic, fix_it u32, replacement_range &C.CXSourceRange) String
pub fn get_diagnostic_fix_it(diag Diagnostic, fix_it u32) (string, SourceRange) {
	mut r := C.CXSourceRange{}
	s := cxstring_to_string(C.clang_getDiagnosticFixIt(diag, fix_it, &r))
	return s, r
}

fn C.clang_getDiagnosticOption(diag Diagnostic, disable &C.CXString) String
pub fn get_diagnostic_option(diag Diagnostic) (string, string) {
	mut disable := C.CXString{0,0}
	opt := cxstring_to_string(C.clang_getDiagnosticOption(diag, &disable))
	return opt, cxstring_to_string(disable)
}

fn C.clang_disposeDiagnosticSet(diags DiagnosticSet)
pub fn dispose_diagnostic_set(diags DiagnosticSet) {
	C.clang_disposeDiagnosticSet(diags)
}

fn C.clang_getChildDiagnostics(d Diagnostic) DiagnosticSet
pub fn get_child_diagnostics(d Diagnostic) DiagnosticSet {
	return C.clang_getChildDiagnostics(d)
}

fn C.clang_getDiagnosticCategoryName(category u32) String
pub fn get_diagnostic_category_name(category u32) string {
	return cxstring_to_string(C.clang_getDiagnosticCategoryName(category))
}

fn C.clang_getDiagnosticInSet(diags DiagnosticSet, index u32) Diagnostic
pub fn get_diagnostic_in_set(diags DiagnosticSet, index u32) Diagnostic {
	return C.clang_getDiagnosticInSet(diags, index)
}

fn C.clang_getNumDiagnosticsInSet(diags DiagnosticSet) u32
pub fn get_num_diagnostics_in_set(diags DiagnosticSet) u32 {
	return C.clang_getNumDiagnosticsInSet(diags)
}

fn C.clang_loadDiagnostics(file &char, error &int, errorString_ &String) DiagnosticSet
pub fn load_diagnostics(file &char, error &int, errorString_ &String) DiagnosticSet {
	return C.clang_loadDiagnostics(file, error, errorString_)
}
