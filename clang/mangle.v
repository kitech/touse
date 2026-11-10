module clang

fn C.clang_Cursor_getMangling(cursor Cursor) String
pub fn cursor_get_mangling(cursor Cursor) string {
	return cxstring_to_string(C.clang_Cursor_getMangling(cursor))
}

fn C.clang_Cursor_getCXXManglings(cursor Cursor) &C.CXStringSet
pub fn cursor_get_cxx_manglings(cursor Cursor) &StringSet {
	return C.clang_Cursor_getCXXManglings(cursor)
}

fn C.clang_Cursor_getObjCManglings(cursor Cursor) &C.CXStringSet
pub fn cursor_get_objc_manglings(cursor Cursor) &StringSet {
	return C.clang_Cursor_getObjCManglings(cursor)
}
