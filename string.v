module clang

fn C.clang_getCString(s C.CXString) &char
fn C.clang_disposeString(s C.CXString)
fn C.clang_disposeStringSet(set &C.CXStringSet)

pub fn cxstring_to_string_dep1(s String) string {
	unsafe {
		cstr := C.clang_getCString(s)
		if cstr == nil {
			C.clang_disposeString(s)
			return ''
		}
		res := cstr.vstring()
		C.clang_disposeString(s)
		return res
	}
}

pub fn cxstring_to_string(s String) string {
    unsafe {
        cstr := C.clang_getCString(s)
        if cstr == nil {
            C.clang_disposeString(s)
            return ''
        }
        // 关键改动：使用 cstring_to_vstring 进行安全复制
        res := cstring_to_vstring(cstr)
        C.clang_disposeString(s)
        return res
    }
}

pub fn dispose_string_set(set &StringSet) {
	C.clang_disposeStringSet(set)
}
