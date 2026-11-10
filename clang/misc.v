module clang

fn C.clang_getClangVersion() String
pub fn get_clang_version() string {
	return cxstring_to_string(C.clang_getClangVersion())
}

fn C.clang_toggleCrashRecovery(is_enabled u32)
pub fn toggle_crash_recovery(is_enabled bool) {
	C.clang_toggleCrashRecovery(if is_enabled { u32(1) } else { u32(0) })
}

fn C.clang_Cursor_Evaluate(cursor Cursor) EvalResult
pub fn cursor_evaluate(cursor Cursor) EvalResult {
	return C.clang_Cursor_Evaluate(cursor)
}

fn C.clang_EvalResult_dispose(result EvalResult)
pub fn eval_result_dispose(result EvalResult) {
	C.clang_EvalResult_dispose(result)
}

fn C.clang_EvalResult_getKind(result EvalResult) EvalResultKind
pub fn eval_result_get_kind(result EvalResult) EvalResultKind {
	return C.clang_EvalResult_getKind(result)
}

fn C.clang_EvalResult_getAsInt(result EvalResult) int
pub fn eval_result_get_as_int(result EvalResult) int {
	return C.clang_EvalResult_getAsInt(result)
}

fn C.clang_EvalResult_getAsDouble(result EvalResult) f64
pub fn eval_result_get_as_double(result EvalResult) f64 {
	return C.clang_EvalResult_getAsDouble(result)
}

fn C.clang_EvalResult_getAsStr(result EvalResult) &char
pub fn eval_result_get_as_str(result EvalResult) &char {
	return C.clang_EvalResult_getAsStr(result)
}

fn C.clang_EvalResult_isUnsignedInt(result EvalResult) u32
pub fn eval_result_is_unsigned_int(result EvalResult) bool {
	return C.clang_EvalResult_isUnsignedInt(result) != 0
}

fn C.clang_EvalResult_getAsUnsigned(result EvalResult) u64
pub fn eval_result_get_as_unsigned(result EvalResult) u64 {
	return C.clang_EvalResult_getAsUnsigned(result)
}

fn C.clang_createCXCursorSet() CursorSet
pub fn create_cursor_set() CursorSet {
	return C.clang_createCXCursorSet()
}

fn C.clang_disposeCXCursorSet(cset CursorSet)
pub fn dispose_cursor_set(cset CursorSet) {
	C.clang_disposeCXCursorSet(cset)
}

fn C.clang_CXCursorSet_contains(cset CursorSet, cursor Cursor) u32
pub fn cursor_set_contains(cset CursorSet, cursor Cursor) bool {
	return C.clang_CXCursorSet_contains(cset, cursor) != 0
}

fn C.clang_CXCursorSet_insert(cset CursorSet, cursor Cursor) u32
pub fn cursor_set_insert(cset CursorSet, cursor Cursor) bool {
	return C.clang_CXCursorSet_insert(cset, cursor) != 0
}

// clang/misc.v 追加

// 文件包含关系遍历（已有 get_inclusions，但回调结构体 CXInclusionVisitor 需确认）
// 版本相关：获取详细版本信息
fn C.clang_getClangVersion() String // 已有
// 崩溃恢复开关（已有 toggle_crash_recovery）

// CursorSet 操作（已有 create/dispose/contains/insert）

// EvalResult 操作（已有 evaluate/dispose/getKind/getAsInt/getAsDouble/getAsStr/isUnsignedInt/getAsUnsigned）

// 线程执行（已有 execute_on_thread）
