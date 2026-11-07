module clang

fn C.clang_getCursorReferenced(cursor Cursor) Cursor
pub fn get_cursor_referenced(cursor Cursor) Cursor {
	return C.clang_getCursorReferenced(cursor)
}

fn C.clang_getCursorDefinition(cursor Cursor) Cursor
pub fn get_cursor_definition(cursor Cursor) Cursor {
	return C.clang_getCursorDefinition(cursor)
}

fn C.clang_isCursorDefinition(cursor Cursor) u32
pub fn is_cursor_definition(cursor Cursor) bool {
	return C.clang_isCursorDefinition(cursor) != 0
}

fn C.clang_getCanonicalCursor(cursor Cursor) Cursor
pub fn get_canonical_cursor(cursor Cursor) Cursor {
	return C.clang_getCanonicalCursor(cursor)
}

fn C.clang_getCursorSemanticParent(cursor Cursor) Cursor
pub fn get_cursor_semantic_parent(cursor Cursor) Cursor {
	return C.clang_getCursorSemanticParent(cursor)
}

fn C.clang_getCursorLexicalParent(cursor Cursor) Cursor
pub fn get_cursor_lexical_parent(cursor Cursor) Cursor {
	return C.clang_getCursorLexicalParent(cursor)
}

fn C.clang_findReferencesInFile(cursor Cursor, file File, visitor CursorAndRangeVisitor) Result
pub fn find_references_in_file(cursor Cursor, file File, visitor CursorAndRangeVisitor) Result {
	return C.clang_findReferencesInFile(cursor, file, visitor)
}

fn C.clang_findIncludesInFile(tu TranslationUnit, file File, visitor CursorAndRangeVisitor) Result
pub fn find_includes_in_file(tu TranslationUnit, file File, visitor CursorAndRangeVisitor) Result {
	return C.clang_findIncludesInFile(tu, file, visitor)
}

// clang/xref.v 追加

// 查找重载声明（C++ 重载集）
fn C.clang_getOverloadedDecl(cursor Cursor, index u32) Cursor
pub fn get_overloaded_decl(cursor Cursor, index u32) Cursor {
	return C.clang_getOverloadedDecl(cursor, index)
}

// 获取重载声明数量
fn C.clang_getNumOverloadedDecls(cursor Cursor) u32
pub fn get_num_overloaded_decls(cursor Cursor) u32 {
	return C.clang_getNumOverloadedDecls(cursor)
}

