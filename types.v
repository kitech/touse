module clang

#include <clang-c/Index.h>

// ============================================================================
// Opaque 句柄
// ============================================================================
pub type Index               = voidptr
pub type TranslationUnit     = voidptr
pub type File                = voidptr
pub type Diagnostic          = voidptr
pub type ClientData          = voidptr
pub type CompletionString    = voidptr
pub type CodeCompleteResults = voidptr
pub type Token               = C.CXToken
pub type Module              = voidptr
pub type TargetInfo          = voidptr
pub type Remapping           = voidptr
pub type CompilationDatabase = voidptr
pub type CompileCommands     = voidptr
pub type CompileCommand      = voidptr
pub type CursorSet           = voidptr
pub type PrintingPolicy      = voidptr
pub type EvalResult          = voidptr
pub type SourceRangeList     = voidptr
pub type IdxClientFile       = voidptr
pub type IdxClientEntity     = voidptr
pub type IdxClientContainer  = voidptr
pub type IndexAction         = voidptr

// ============================================================================
// 结构体（C 侧保留 CX 前缀以匹配 ABI）
// ============================================================================
@[typedef]
pub struct C.CXString {
pub mut:
	data          &char
	private_flags u32
}
pub type String = C.CXString

@[typedef]
pub struct C.CXCursor {
pub mut:
	kind  CursorKind
	xdata int
	data  [3]voidptr
}
pub type Cursor = C.CXCursor

@[typedef]
pub struct C.CXType {
pub mut:
	kind TypeKind
	data [2]voidptr
}
pub type Type = C.CXType

@[typedef]
pub struct C.CXSourceLocation {
pub mut:
	ptr_data [2]voidptr
	int_data u32
}
pub type SourceLocation = C.CXSourceLocation

@[typedef]
pub struct C.CXSourceRange {
pub mut:
	ptr_data       [2]voidptr
	begin_int_data u32
	end_int_data   u32
}
pub type SourceRange = C.CXSourceRange

@[typedef]
pub struct C.CXUnsavedFile {
pub mut:
	filename &char
	contents &char
	length   usize
}
pub type UnsavedFile = C.CXUnsavedFile

@[typedef]
pub struct C.CXToken {
pub mut:
	int_data [4]u32
	ptr_data voidptr
}
pub type TokenStruct = C.CXToken

@[typedef]
pub struct C.CXVersion {
pub mut:
	major    int
	minor    int
	subminor int
}
pub type Version = C.CXVersion

@[typedef]
pub struct C.CXPlatformAvailability {
pub mut:
	platform    String
	introduced  C.CXVersion
	deprecated  C.CXVersion
	obsoleted   C.CXVersion
	unavailable int
	message     String
}
pub type PlatformAvailability = C.CXPlatformAvailability

@[typedef]
pub struct C.CXCompletionResult {
pub mut:
	cursor_kind       CursorKind
	completion_string CompletionString
}
pub type CompletionResult = C.CXCompletionResult

@[typedef]
pub struct C.CXCodeCompleteResults {
pub mut:
	results     &C.CXCompletionResult
	num_results u32
}
pub type CodeCompleteResultsStruct = C.CXCodeCompleteResults

@[typedef]
pub struct C.CXCursorAndRangeVisitor {
pub mut:
	context voidptr
	visit   voidptr
}
pub type CursorAndRangeVisitor = C.CXCursorAndRangeVisitor

@[typedef]
pub struct C.CXIdxLoc {
pub mut:
	ptr_data [2]voidptr
	int_data u32
}
pub type IdxLoc = C.CXIdxLoc

@[typedef]
pub struct C.CXIdxIncludedFileInfo {
pub mut:
	hash_loc         IdxLoc
	filename         &char
	file             File
	is_import        int
	is_angled        int
	is_module_import int
}
pub type IdxIncludedFileInfo = C.CXIdxIncludedFileInfo

@[typedef]
pub struct C.CXStringSet {
pub mut:
	strings &C.CXString
	count   u32
}
pub type StringSet = C.CXStringSet

@[typedef]
pub struct C.CXIndexOptions {
pub mut:
	sizeof_options  u32
	threading_model int
}
pub type IndexOptions = C.CXIndexOptions

@[typedef]
pub struct C.CXTUResourceUsageEntry {
pub mut:
	kind   int
	amount usize
}
pub type TUResourceUsageEntry = C.CXTUResourceUsageEntry

@[typedef]
pub struct C.CXTUResourceUsage {
pub mut:
	data        voidptr
	num_entries u32
	entries     &C.CXTUResourceUsageEntry
}
pub type TUResourceUsage = C.CXTUResourceUsage

// ============================================================================
// 枚举
// ============================================================================
pub enum ChildVisitResult {
	continue_ = 0
	recurse   = 1
	break_    = 2
}

pub enum VisitorResult {
	break_    = 0
	continue_ = 1
}

pub enum Result {
	success = 0
	failure = 1
}

pub enum DiagnosticSeverity {
	ignored = 0
	note    = 1
	warning = 2
	error_  = 3
	fatal   = 4
}

pub enum TokenKind {
	punctuation = 0
	keyword     = 1
	identifier  = 2
	literal     = 3
	comment     = 4
}

pub enum AvailabilityKind {
	available      = 0
	deprecated     = 1
	not_available  = 2
	not_accessible = 3
}

pub enum LinkageKind {
	invalid         = 0
	no_linkage      = 1
	internal        = 2
	unique_external = 3
	external        = 4
}

pub enum VisibilityKind {
	invalid    = 0
	hidden     = 1
	protected_ = 2
	default_   = 3
}

pub enum LanguageKind {
	invalid   = 0
	c         = 1
	objc      = 2
	cplusplus = 3
}

pub enum TLSKind {
	none    = 0
	dynamic = 1
	static_ = 2
}

pub enum RefQualifierKind {
	none   = 0
	lvalue = 1
	rvalue = 2
}

pub enum TypeLayoutError {
	invalid            = -1
	incomplete         = -2
	dependent          = -3
	not_constant_size  = -4
	invalid_field_name = -5
	undeduced          = -6
}

pub enum EvalResultKind {
	int_   = 1
	float_ = 2
	other  = 3
	str_   = 4
}

pub enum StorageClass {
	invalid                 = 0
	none                    = 1
	extern                  = 2
	static_                 = 3
	private_extern          = 4
	opencl_work_group_local = 5
	auto_                   = 6
	register                = 7
}

pub enum ExceptionSpecificationKind {
	none                    = 0
	dynamic_none            = 1
	dynamic                 = 2
	ms_any                  = 3
	basic_noexcept          = 4
	computed_noexcept       = 5
	unevaluated             = 6
	unevaluated_unevaluated = 7
}

pub enum CursorKind {
	invalid            = 0
	unexposed_decl     = 1
	typedef_decl       = 2
	struct_decl        = 3
	union_decl         = 4
	class_decl         = 5
	enum_decl          = 6
	field_decl         = 7
	enum_constant_decl = 8
	function_decl      = 9
	var_decl           = 10
	parm_decl          = 11
	// 完整 CursorKind 约 200+ 项，可按 Index.h 逐项补齐
}

pub enum TypeKind {
	invalid    = 0
	unexposed  = 1
	void_      = 2
	bool_      = 3
	char_u     = 4
	uchar      = 5
	char16     = 6
	char32     = 7
	ushort     = 8
	uint       = 9
	ulong      = 10
	ulonglong  = 11
	uint128    = 12
	char_s     = 13
	schar      = 14
	wchar      = 15
	short      = 16
	int_       = 17
	long_      = 18
	longlong   = 19
	int128     = 20
	float_     = 21
	double_    = 22
	longdouble = 23
	nullptr    = 24
	overload   = 25
	// 完整 TypeKind 约 150+ 项，可按 Index.h 逐项补齐
}

// ============================================================================
// 回调类型
// ============================================================================
pub type CXCursorVisitor = fn (cursor Cursor, parent Cursor, client_data ClientData) ChildVisitResult
pub type CXInclusionVisitor = fn (included_file File, inclusion_stack &SourceLocation, include_len u32, client_data ClientData) voidptr
