module clang

fn C.clang_CXXConstructor_isConvertingConstructor(cursor Cursor) u32
pub fn cxx_constructor_is_converting_constructor(cursor Cursor) bool {
	return C.clang_CXXConstructor_isConvertingConstructor(cursor) != 0
}

fn C.clang_CXXConstructor_isCopyConstructor(cursor Cursor) u32
pub fn cxx_constructor_is_copy_constructor(cursor Cursor) bool {
	return C.clang_CXXConstructor_isCopyConstructor(cursor) != 0
}

fn C.clang_CXXConstructor_isDefaultConstructor(cursor Cursor) u32
pub fn cxx_constructor_is_default_constructor(cursor Cursor) bool {
	return C.clang_CXXConstructor_isDefaultConstructor(cursor) != 0
}

fn C.clang_CXXConstructor_isMoveConstructor(cursor Cursor) u32
pub fn cxx_constructor_is_move_constructor(cursor Cursor) bool {
	return C.clang_CXXConstructor_isMoveConstructor(cursor) != 0
}

fn C.clang_CXXField_isMutable(cursor Cursor) u32
pub fn cxx_field_is_mutable(cursor Cursor) bool {
	return C.clang_CXXField_isMutable(cursor) != 0
}

fn C.clang_CXXMethod_isDefaulted(cursor Cursor) u32
pub fn cxx_method_is_defaulted(cursor Cursor) bool {
	return C.clang_CXXMethod_isDefaulted(cursor) != 0
}

fn C.clang_CXXMethod_isDeleted(cursor Cursor) u32
pub fn cxx_method_is_deleted(cursor Cursor) bool {
	return C.clang_CXXMethod_isDeleted(cursor) != 0
}

fn C.clang_CXXMethod_isPureVirtual(cursor Cursor) u32
pub fn cxx_method_is_pure_virtual(cursor Cursor) bool {
	return C.clang_CXXMethod_isPureVirtual(cursor) != 0
}

fn C.clang_CXXMethod_isStatic(cursor Cursor) u32
pub fn cxx_method_is_static(cursor Cursor) bool {
	return C.clang_CXXMethod_isStatic(cursor) != 0
}

fn C.clang_CXXMethod_isVirtual(cursor Cursor) u32
pub fn cxx_method_is_virtual(cursor Cursor) bool {
	return C.clang_CXXMethod_isVirtual(cursor) != 0
}

fn C.clang_CXXMethod_isCopyAssignmentOperator(cursor Cursor) u32
pub fn cxx_method_is_copy_assignment_operator(cursor Cursor) bool {
	return C.clang_CXXMethod_isCopyAssignmentOperator(cursor) != 0
}

fn C.clang_CXXMethod_isMoveAssignmentOperator(cursor Cursor) u32
pub fn cxx_method_is_move_assignment_operator(cursor Cursor) bool {
	return C.clang_CXXMethod_isMoveAssignmentOperator(cursor) != 0
}

fn C.clang_CXXMethod_isExplicit(cursor Cursor) u32
pub fn cxx_method_is_explicit(cursor Cursor) bool {
	return C.clang_CXXMethod_isExplicit(cursor) != 0
}

fn C.clang_CXXMethod_isConst(cursor Cursor) u32
pub fn cxx_method_is_const(cursor Cursor) bool {
	return C.clang_CXXMethod_isConst(cursor) != 0
}

fn C.clang_CXXRecord_isAbstract(cursor Cursor) u32
pub fn cxx_record_is_abstract(cursor Cursor) bool {
	return C.clang_CXXRecord_isAbstract(cursor) != 0
}

fn C.clang_EnumDecl_isScoped(cursor Cursor) u32
pub fn enum_decl_is_scoped(cursor Cursor) bool {
	return C.clang_EnumDecl_isScoped(cursor) != 0
}

fn C.clang_getTemplateCursorKind(cursor Cursor) CursorKind
pub fn get_template_cursor_kind(cursor Cursor) CursorKind {
	return C.clang_getTemplateCursorKind(cursor)
}

fn C.clang_getSpecializedCursorTemplate(cursor Cursor) Cursor
pub fn get_specialized_cursor_template(cursor Cursor) Cursor {
	return C.clang_getSpecializedCursorTemplate(cursor)
}

fn C.clang_getCursorReferenceNameRange(cursor Cursor, name_flags u32, piece_index u32) SourceRange
pub fn get_cursor_reference_name_range(cursor Cursor, name_flags u32, piece_index u32) SourceRange {
	return C.clang_getCursorReferenceNameRange(cursor, name_flags, piece_index)
}

fn C.clang_getCursorBinaryOperatorKind(cursor Cursor) int
pub fn get_cursor_binary_operator_kind(cursor Cursor) int {
	return C.clang_getCursorBinaryOperatorKind(cursor)
}

/*
fn C.clang_getCursorUnaryOperatorKind(cursor Cursor) int
pub fn get_cursor_unary_operator_kind(cursor Cursor) int {
	return C.clang_getCursorUnaryOperatorKind(cursor)
}
*/
