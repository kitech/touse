module clang

fn C.clang_getTranslationUnitCursor(tu TranslationUnit) Cursor
pub fn get_translation_unit_cursor(tu TranslationUnit) Cursor {
	return C.clang_getTranslationUnitCursor(tu)
}

fn C.clang_visitChildren(parent Cursor, visitor CXCursorVisitor, client_data ClientData) u32
pub fn visit_children(parent Cursor, visitor CXCursorVisitor, client_data ClientData) u32 {
	return C.clang_visitChildren(parent, visitor, client_data)
}

fn C.clang_getInclusions(tu TranslationUnit, visitor CXInclusionVisitor, client_data ClientData)
pub fn get_inclusions(tu TranslationUnit, visitor CXInclusionVisitor, client_data ClientData) {
	C.clang_getInclusions(tu, visitor, client_data)
}

// clang/traversal.v 追加

pub type CXCursorVisitorBlock = voidptr

fn C.clang_visitChildrenWithBlock(parent Cursor, block CXCursorVisitorBlock) u32
pub fn visit_children_with_block(parent Cursor, block CXCursorVisitorBlock) u32 {
	return C.clang_visitChildrenWithBlock(parent, block)
}
