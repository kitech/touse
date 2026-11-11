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

fn C.clang_Cursor_getStorageClass(cursor Cursor) StorageClass
pub fn get_cursor_storage_class(cursor Cursor) StorageClass {
	return C.clang_Cursor_getStorageClass(cursor)
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

fn C.clang_Cursor_getBinaryOpcode(c Cursor) int
pub fn cursor_get_binary_opcode(c Cursor) int {
	if has_major(19) {
		return C.clang_Cursor_getBinaryOpcode(c)
	}

	return 0
}

fn C.clang_Cursor_getBinaryOpcodeStr(op int) String
pub fn cursor_get_binary_opcode_str(op int) string {
	if has_major(19) {
		return cxstring_to_string(C.clang_Cursor_getBinaryOpcodeStr(op))
	}

	return ''
}

fn C.clang_Cursor_getGCCAssemblyInput(cursor Cursor, index u32, constraint &String, expr &Cursor) u32
pub fn cursor_get_gcc_assembly_input(cursor Cursor, index u32, constraint &String, expr &Cursor) u32 {
	if has_major(21) {
		return C.clang_Cursor_getGCCAssemblyInput(cursor, index, constraint, expr)
	}

	return 0
}

fn C.clang_Cursor_getGCCAssemblyOutput(cursor Cursor, index u32, constraint &String, expr &Cursor) u32
pub fn cursor_get_gcc_assembly_output(cursor Cursor, index u32, constraint &String, expr &Cursor) u32 {
	if has_major(21) {
		return C.clang_Cursor_getGCCAssemblyOutput(cursor, index, constraint, expr)
	}

	return 0
}

fn C.clang_Cursor_getModule(c Cursor) Module
pub fn cursor_get_module(c Cursor) Module {
	return C.clang_Cursor_getModule(c)
}

fn C.clang_Cursor_getNumTemplateArguments(c Cursor) int
pub fn cursor_get_num_template_arguments(c Cursor) int {
	return C.clang_Cursor_getNumTemplateArguments(c)
}

fn C.clang_Cursor_getObjCDeclQualifiers(c Cursor) u32
pub fn cursor_get_obj_c_decl_qualifiers(c Cursor) u32 {
	return C.clang_Cursor_getObjCDeclQualifiers(c)
}

fn C.clang_Cursor_getObjCPropertyAttributes(c Cursor, reserved u32) u32
pub fn cursor_get_obj_c_property_attributes(c Cursor, reserved u32) u32 {
	return C.clang_Cursor_getObjCPropertyAttributes(c, reserved)
}

fn C.clang_Cursor_getObjCPropertyGetterName(c Cursor) String
pub fn cursor_get_obj_c_property_getter_name(c Cursor) string {
	return cxstring_to_string(C.clang_Cursor_getObjCPropertyGetterName(c))
}

fn C.clang_Cursor_getObjCPropertySetterName(c Cursor) String
pub fn cursor_get_obj_c_property_setter_name(c Cursor) string {
	return cxstring_to_string(C.clang_Cursor_getObjCPropertySetterName(c))
}

fn C.clang_Cursor_getSpellingNameRange(arg0 Cursor, pieceIndex_ u32, options u32) SourceRange
pub fn cursor_get_spelling_name_range(arg0 Cursor, pieceIndex_ u32, options u32) SourceRange {
	return C.clang_Cursor_getSpellingNameRange(arg0, pieceIndex_, options)
}

fn C.clang_Cursor_getTemplateArgumentKind(c Cursor, i u32) int
pub fn cursor_get_template_argument_kind(c Cursor, i u32) int {
	return C.clang_Cursor_getTemplateArgumentKind(c, i)
}

fn C.clang_Cursor_getTemplateArgumentType(c Cursor, i u32) Type
pub fn cursor_get_template_argument_type(c Cursor, i u32) Type {
	return C.clang_Cursor_getTemplateArgumentType(c, i)
}

fn C.clang_Cursor_getTemplateArgumentUnsignedValue(c Cursor, i u32) u64
pub fn cursor_get_template_argument_unsigned_value(c Cursor, i u32) u64 {
	return C.clang_Cursor_getTemplateArgumentUnsignedValue(c, i)
}

fn C.clang_Cursor_getTemplateArgumentValue(c Cursor, i u32) i64
pub fn cursor_get_template_argument_value(c Cursor, i u32) i64 {
	return C.clang_Cursor_getTemplateArgumentValue(c, i)
}

fn C.clang_Cursor_getTranslationUnit(arg0 Cursor) TranslationUnit
pub fn cursor_get_translation_unit(arg0 Cursor) TranslationUnit {
	return C.clang_Cursor_getTranslationUnit(arg0)
}

fn C.clang_Cursor_hasAttrs(c Cursor) u32
pub fn cursor_has_attrs(c Cursor) u32 {
	return C.clang_Cursor_hasAttrs(c)
}

fn C.clang_Cursor_isBitField(c Cursor) u32
pub fn cursor_is_bit_field(c Cursor) u32 {
	return C.clang_Cursor_isBitField(c)
}

fn C.clang_Cursor_isExternalSymbol(c Cursor, language &String, definedIn_ &String, isGenerated_ &u32) u32
pub fn cursor_is_external_symbol(c Cursor, language &String, definedIn_ &String, isGenerated_ &u32) u32 {
	return C.clang_Cursor_isExternalSymbol(c, language, definedIn_, isGenerated_)
}

fn C.clang_Cursor_isFunctionInlined(c Cursor) u32
pub fn cursor_is_function_inlined(c Cursor) u32 {
	return C.clang_Cursor_isFunctionInlined(c)
}

fn C.clang_Cursor_isMacroBuiltin(c Cursor) u32
pub fn cursor_is_macro_builtin(c Cursor) u32 {
	return C.clang_Cursor_isMacroBuiltin(c)
}

fn C.clang_Cursor_isMacroFunctionLike(c Cursor) u32
pub fn cursor_is_macro_function_like(c Cursor) u32 {
	return C.clang_Cursor_isMacroFunctionLike(c)
}

fn C.clang_Cursor_isObjCOptional(c Cursor) u32
pub fn cursor_is_obj_c_optional(c Cursor) u32 {
	return C.clang_Cursor_isObjCOptional(c)
}

fn C.clang_disposeOverriddenCursors(overridden &Cursor)
pub fn dispose_overridden_cursors(overridden &Cursor) {
	C.clang_disposeOverriddenCursors(overridden)
}

fn C.clang_getCursorAvailability(cursor Cursor) int
pub fn get_cursor_availability(cursor Cursor) int {
	return C.clang_getCursorAvailability(cursor)
}

fn C.clang_getCursorCompletionString(cursor Cursor) CompletionString
pub fn get_cursor_completion_string(cursor Cursor) CompletionString {
	return C.clang_getCursorCompletionString(cursor)
}

fn C.clang_getCursorResultType(c Cursor) Type
pub fn get_cursor_result_type(c Cursor) Type {
	return C.clang_getCursorResultType(c)
}

fn C.clang_getCursorUSR(arg0 Cursor) String
pub fn get_cursor_usr(arg0 Cursor) string {
	return cxstring_to_string(C.clang_getCursorUSR(arg0))
}

fn C.clang_getOverriddenCursors(cursor Cursor, overridden &&Cursor, num_overridden &u32)
pub fn get_overridden_cursors(cursor Cursor, overridden &&Cursor, num_overridden &u32) {
	C.clang_getOverriddenCursors(cursor, overridden, num_overridden)
}
