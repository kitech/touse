module clang

fn C.clang_getNullCursor() Cursor
pub fn get_null_cursor() Cursor {
	return C.clang_getNullCursor()
}

fn C.clang_equalCursors(a Cursor, b Cursor) u32
pub fn equal_cursors(a Cursor, b Cursor) bool {
	return C.clang_equalCursors(a, b) != 0
}

fn C.clang_Cursor_isNull(c Cursor) int
pub fn cursor_is_null(c Cursor) bool {
	return C.clang_Cursor_isNull(c) != 0
}

fn C.clang_hashCursor(c Cursor) u32
pub fn hash_cursor(c Cursor) u32 {
	return C.clang_hashCursor(c)
}

fn C.clang_getCursorKind(c Cursor) CursorKind
pub fn get_cursor_kind(c Cursor) CursorKind {
	return C.clang_getCursorKind(c)
}

fn C.clang_isDeclaration(kind CursorKind) u32
pub fn is_declaration(kind CursorKind) bool {
	return C.clang_isDeclaration(kind) != 0
}

fn C.clang_isInvalidDeclaration(c Cursor) u32
pub fn is_invalid_declaration(c Cursor) bool {
	return C.clang_isInvalidDeclaration(c) != 0
}

fn C.clang_isReference(kind CursorKind) u32
pub fn is_reference(kind CursorKind) bool {
	return C.clang_isReference(kind) != 0
}

fn C.clang_isExpression(kind CursorKind) u32
pub fn is_expression(kind CursorKind) bool {
	return C.clang_isExpression(kind) != 0
}

fn C.clang_isStatement(kind CursorKind) u32
pub fn is_statement(kind CursorKind) bool {
	return C.clang_isStatement(kind) != 0
}

fn C.clang_isAttribute(kind CursorKind) u32
pub fn is_attribute(kind CursorKind) bool {
	return C.clang_isAttribute(kind) != 0
}

fn C.clang_isInvalid(kind CursorKind) u32
pub fn is_invalid(kind CursorKind) bool {
	return C.clang_isInvalid(kind) != 0
}

fn C.clang_isTranslationUnit(kind CursorKind) u32
pub fn is_translation_unit(kind CursorKind) bool {
	return C.clang_isTranslationUnit(kind) != 0
}

fn C.clang_isPreprocessing(kind CursorKind) u32
pub fn is_preprocessing(kind CursorKind) bool {
	return C.clang_isPreprocessing(kind) != 0
}

fn C.clang_isUnexposed(kind CursorKind) u32
pub fn is_unexposed(kind CursorKind) bool {
	return C.clang_isUnexposed(kind) != 0
}

fn C.clang_getCursorSpelling(cursor Cursor) String
pub fn get_cursor_spelling(cursor Cursor) string {
	return cxstring_to_string(C.clang_getCursorSpelling(cursor))
}

fn C.clang_getCursorDisplayName(cursor Cursor) String
pub fn get_cursor_display_name(cursor Cursor) string {
	return cxstring_to_string(C.clang_getCursorDisplayName(cursor))
}

fn C.clang_getCursorLinkage(cursor Cursor) LinkageKind
pub fn get_cursor_linkage(cursor Cursor) LinkageKind {
	return C.clang_getCursorLinkage(cursor)
}

fn C.clang_getCursorVisibility(cursor Cursor) VisibilityKind
pub fn get_cursor_visibility(cursor Cursor) VisibilityKind {
	return C.clang_getCursorVisibility(cursor)
}

fn C.clang_getCursorLanguage(cursor Cursor) LanguageKind
pub fn get_cursor_language(cursor Cursor) LanguageKind {
	return C.clang_getCursorLanguage(cursor)
}

fn C.clang_getCursorTLSKind(cursor Cursor) TLSKind
pub fn get_cursor_tls_kind(cursor Cursor) TLSKind {
	return C.clang_getCursorTLSKind(cursor)
}

fn C.clang_getCursorStorageClass(cursor Cursor) StorageClass
pub fn get_cursor_storage_class(cursor Cursor) StorageClass {
	return C.clang_getCursorStorageClass(cursor)
}

fn C.clang_getCursorExceptionSpecificationType(cursor Cursor) ExceptionSpecificationKind
pub fn get_cursor_exception_specification_type(cursor Cursor) ExceptionSpecificationKind {
	return C.clang_getCursorExceptionSpecificationType(cursor)
}

fn C.clang_Cursor_isAnonymous(cursor Cursor) u32
pub fn cursor_is_anonymous(cursor Cursor) bool {
	return C.clang_Cursor_isAnonymous(cursor) != 0
}

fn C.clang_Cursor_isAnonymousRecordDecl(cursor Cursor) u32
pub fn cursor_is_anonymous_record_decl(cursor Cursor) bool {
	return C.clang_Cursor_isAnonymousRecordDecl(cursor) != 0
}

fn C.clang_Cursor_isInlineNamespace(cursor Cursor) u32
pub fn cursor_is_inline_namespace(cursor Cursor) bool {
	return C.clang_Cursor_isInlineNamespace(cursor) != 0
}

fn C.clang_Cursor_getBriefCommentText(cursor Cursor) String
pub fn cursor_get_brief_comment_text(cursor Cursor) string {
	return cxstring_to_string(C.clang_Cursor_getBriefCommentText(cursor))
}

fn C.clang_Cursor_getRawCommentText(cursor Cursor) String
pub fn cursor_get_raw_comment_text(cursor Cursor) string {
	return cxstring_to_string(C.clang_Cursor_getRawCommentText(cursor))
}

fn C.clang_getCursorPrettyPrinted(cursor Cursor, policy PrintingPolicy) String
pub fn get_cursor_pretty_printed(cursor Cursor, policy PrintingPolicy) string {
	return cxstring_to_string(C.clang_getCursorPrettyPrinted(cursor, policy))
}

fn C.clang_getCursorPrintingPolicy(cursor Cursor) PrintingPolicy
pub fn get_cursor_printing_policy(cursor Cursor) PrintingPolicy {
	return C.clang_getCursorPrintingPolicy(cursor)
}

fn C.clang_PrintingPolicy_dispose(policy PrintingPolicy)
pub fn printing_policy_dispose(policy PrintingPolicy) {
	C.clang_PrintingPolicy_dispose(policy)
}

fn C.clang_getCursorPlatformAvailability(cursor Cursor, always_deprecated &int, deprecated_message &C.CXString, always_unavailable &int, unavailable_message &C.CXString, availability &C.CXPlatformAvailability, availability_size int) int
pub fn get_cursor_platform_availability(cursor Cursor, buf &PlatformAvailability, buf_size int) (int, int, string, int, string) {
	mut always_dep := int(0)
	mut dep_msg := C.CXString{0,0}
	mut always_unavail := int(0)
	mut unavail_msg := C.CXString{0,0}
	n := C.clang_getCursorPlatformAvailability(cursor, &always_dep, &dep_msg, &always_unavail, &unavail_msg, buf, buf_size)
	return n, always_dep, cxstring_to_string(dep_msg), always_unavail, cxstring_to_string(unavail_msg)
}

fn C.clang_disposeCXPlatformAvailability(availability &C.CXPlatformAvailability)
pub fn dispose_platform_availability(availability &PlatformAvailability) {
	C.clang_disposeCXPlatformAvailability(availability)
}

fn C.clang_Cursor_getVarDeclInitializer(cursor Cursor) Cursor
pub fn cursor_get_var_decl_initializer(cursor Cursor) Cursor {
	return C.clang_Cursor_getVarDeclInitializer(cursor)
}

fn C.clang_Cursor_hasVarDeclGlobalStorage(cursor Cursor) int
pub fn cursor_has_var_decl_global_storage(cursor Cursor) int {
	return C.clang_Cursor_hasVarDeclGlobalStorage(cursor)
}

fn C.clang_Cursor_hasVarDeclExternalStorage(cursor Cursor) int
pub fn cursor_has_var_decl_external_storage(cursor Cursor) int {
	return C.clang_Cursor_hasVarDeclExternalStorage(cursor)
}

fn C.clang_Cursor_getObjCSelectorIndex(cursor Cursor) int
pub fn cursor_get_objc_selector_index(cursor Cursor) int {
	return C.clang_Cursor_getObjCSelectorIndex(cursor)
}

fn C.clang_Cursor_isDynamicCall(cursor Cursor) int
pub fn cursor_is_dynamic_call(cursor Cursor) bool {
	return C.clang_Cursor_isDynamicCall(cursor) != 0
}

fn C.clang_Cursor_getReceiverType(cursor Cursor) Type
pub fn cursor_get_receiver_type(cursor Cursor) Type {
	return C.clang_Cursor_getReceiverType(cursor)
}

// clang/cursor.v 追加

fn C.clang_Cursor_getNumArguments(cursor Cursor) int
pub fn cursor_get_num_arguments(cursor Cursor) int {
	return C.clang_Cursor_getNumArguments(cursor)
}

fn C.clang_Cursor_getArgument(cursor Cursor, i u32) Cursor
pub fn cursor_get_argument(cursor Cursor, i u32) Cursor {
	return C.clang_Cursor_getArgument(cursor, i)
}

fn C.clang_getCursorUnaryOperatorKind(cursor Cursor) int
pub fn get_cursor_unary_operator_kind(cursor Cursor) int {
	return C.clang_getCursorUnaryOperatorKind(cursor)
}


// clang/cursor.v 追加

// 是否为“函数/方法”的可变参数声明
fn C.clang_Cursor_isVariadic(cursor Cursor) u32
pub fn cursor_is_variadic(cursor Cursor) bool {
	return C.clang_Cursor_isVariadic(cursor) != 0
}

// 是否为“函数/方法”的默认参数
fn C.clang_Cursor_isDefaulted(cursor Cursor) u32 // 已有 cxx_method_is_defaulted，但这是通用版本
pub fn cursor_is_defaulted(cursor Cursor) bool {
	return C.clang_Cursor_isDefaulted(cursor) != 0
}

// 是否为“函数/方法”的纯虚函数（通用版本，已有 CXXMethod 版本）
fn C.clang_Cursor_isPureVirtual(cursor Cursor) u32
pub fn cursor_is_pure_virtual(cursor Cursor) bool {
	return C.clang_Cursor_isPureVirtual(cursor) != 0
}

// 是否为“函数/方法”的静态函数（通用版本）
fn C.clang_Cursor_isStatic(cursor Cursor) u32
pub fn cursor_is_static(cursor Cursor) bool {
	return C.clang_Cursor_isStatic(cursor) != 0
}

// 是否为“函数/方法”的虚函数（通用版本）
fn C.clang_Cursor_isVirtual(cursor Cursor) u32
pub fn cursor_is_virtual(cursor Cursor) bool {
	return C.clang_Cursor_isVirtual(cursor) != 0
}

// 是否为“函数/方法”的显式构造函数（通用版本）
fn C.clang_Cursor_isExplicit(cursor Cursor) u32
pub fn cursor_is_explicit(cursor Cursor) bool {
	return C.clang_Cursor_isExplicit(cursor) != 0
}

// 是否为“函数/方法”的 const 方法（通用版本）
fn C.clang_Cursor_isConst(cursor Cursor) u32
pub fn cursor_is_const(cursor Cursor) bool {
	return C.clang_Cursor_isConst(cursor) != 0
}
