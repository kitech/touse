// ============================================================================
// verauto.c —— libclang 版本粗判（依据 clang-c/Index.h 自带版本宏）
// ============================================================================
// CINDEX_VERSION_MINOR 变化史（实测各 release tag）：
//   LLVM 13/14/15 → 62
//   LLVM 16       → 63
//   LLVM 17+      → 64（官方冻结 CINDEX 稳定 ABI，只加不减）
// 精确大版本请用 V 侧 clang_major()（解析 clang_getClangVersion 字符串）。
// 本文件只提供"头文件宏"层面的粗判，供 V 侧在字符串解析意外失败时兜底。

#include <clang-c/Index.h>

// 返回粗版本族：15（含更早）/ 16 / 17（含更新）
int vclang_index_family(void) {
#if CINDEX_VERSION >= CINDEX_VERSION_ENCODE(0, 64)
	return 17;
#elif CINDEX_VERSION >= CINDEX_VERSION_ENCODE(0, 63)
	return 16;
#else
	return 15;
#endif
}

// ============================================================================
// 版本号缓存（V 侧 clang_major() 使用；避免 V 全局变量需要 -enable-globals）
// ============================================================================
static int vclang_cached_major = 0;

void vclang_set_cached_major(int m) { vclang_cached_major = m; }

int vclang_get_cached_major(void) { return vclang_cached_major; }
