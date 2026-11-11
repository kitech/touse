module clang

#flag @DIR/verauto.c

// ============================================================================
// 版本检测（运行时，自动，无 -d 参数）
// ============================================================================
// clang_major() 精确大版本：解析 clang_getClangVersion() 输出
//   "clang version 23.1.4" → 23
// 解析失败时回退 verauto.c 的 vclang_index_family()（15/16/17 三档粗判）。
// 版本敏感符号（某版本才新增的 API）用 has_major(N) 守卫。

fn C.vclang_index_family() int

// C 侧缓存的版本号（verauto.c 提供 setter，避免 V 全局变量依赖 -enable-globals）
fn C.vclang_set_cached_major(m int)
fn C.vclang_get_cached_major() int

pub fn clang_major() int {
	mut m := C.vclang_get_cached_major()
	if m != 0 {
		return m
	}
	v := get_clang_version()
	if v.contains('version ') {
		s := v.all_after('version ').trim_space()
		s = s.all_before('.')
		m = s.int()
	}
	if m <= 0 {
		m = C.vclang_index_family() // 兜底粗判
	}
	C.vclang_set_cached_major(m)
	return m
}

// 是否 >= N（供版本敏感符号守卫）
pub fn has_major(n int) bool {
	return clang_major() >= n
}
