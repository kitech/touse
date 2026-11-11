module clang

// IndexerCallbacks 及其依赖的 CXIdx* 结构体类型众多，这里仅列出核心句柄和结构体。
// 其余回调函数指针类型与结构体可按 Index.h 中 CXIdxClient* 定义补充。

pub type IndexerCallbacks = voidptr  // 具体结构体按需建模

fn C.clang_indexTranslationUnit(index_action IndexAction, client_data ClientData, callbacks IndexerCallbacks, cb_size u32, index_options u32, out_tu &TranslationUnit) int
pub fn index_translation_unit(index_action IndexAction, client_data ClientData, callbacks IndexerCallbacks, cb_size u32, index_options u32, out_tu &TranslationUnit) int {
	return C.clang_indexTranslationUnit(index_action, client_data, callbacks, cb_size, index_options, out_tu)
}

fn C.clang_indexLoc_getFileLocation(loc IdxLoc, indexFile &IdxClientFile, file &File, line &u32, column &u32, offset &u32) voidptr
pub fn index_loc_get_file_location(loc IdxLoc) (IdxClientFile, File, u32, u32, u32) {
	mut idx_file := IdxClientFile(nil)
	mut f := File(nil)
	mut line := u32(0)
	mut col := u32(0)
	mut off := u32(0)
	C.clang_indexLoc_getFileLocation(loc, &idx_file, &f, &line, &col, &off)
	return idx_file, f, line, col, off
}


// clang/indexing.v 追加（骨架，完整实现需按 Index.h 中 CXIdx* 定义逐项补充）

// IndexerCallbacks 结构体（包含约 10 个函数指针字段）
@[typedef]
pub struct C.IndexerCallbacks {
pub mut:
	abort_query            voidptr
	diagnostic             voidptr
	file                     voidptr
	entered_main_file      voidptr
	pp_included_file       voidptr
	imported_ast_file      voidptr
	started_translation_unit voidptr
	ended_translation_unit   voidptr
}

// CXIdxLoc 相关操作
fn C.clang_indexLoc_getFileLocation(loc C.CXIdxLoc, indexFile &IdxClientFile, file &File, line &u32, column &u32, offset &u32) voidptr // 已有
fn C.clang_indexLoc_getCXSourceLocation(loc C.CXIdxLoc) SourceLocation
pub fn index_loc_get_cx_source_location(loc IdxLoc) SourceLocation {
	return C.clang_indexLoc_getCXSourceLocation(loc)
}

// CXIdxClient* 句柄的释放函数（如有）
// CXIdxEntity* / CXIdxContainer* 查询函数需按 Index.h 定义补充

