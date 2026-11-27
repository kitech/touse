// 动态加载入口：直接混编 gumbo_dyn.c，不生成 .o，不改 C 源。
module htmpar

import vcp.tcchf

// 让生成的 C 代码拿到 gumbo_* 的真实原型，和 gumbo_dyn.c 的上游头 include 一致。

// 这两个必须include一个，否则有可能导致非int返回值的函数错误的当int了
//#include <gumbo.h>
#include <@DIR/gumbo_dyn.c>
//#flag @DIR/gumbo_dyn.o

// dyn.c 独有、gumbo.h 未声明的符号：让 V 直接输出 extern 原型，
// 避免指针返回被 C 当成隐式 int 而截断。
fn C.gumbo_libok() int
fn C.gumbo_dyn_init(path &char) int
fn C.gumbo_dyn_cleanup()
fn C.gumbo_dyn_has_symbol(name &char) int
fn C.gumbo_dyn_default_options() voidptr

fn C.gumbo_parse(buffer &char) voidptr
fn C.gumbo_parse_with_options(options voidptr, buffer &char, length usize) voidptr
fn C.gumbo_destroy_output(options voidptr, output voidptr)

fn C.gumbo_string_equals(a voidptr, b voidptr) bool
fn C.gumbo_string_equals_ignore_case(a voidptr, b voidptr) bool
fn C.gumbo_vector_index_of(vector voidptr, element voidptr) int
fn C.gumbo_tag_is_void(tag int) bool
fn C.gumbo_normalized_tagname(tag int) &char
fn C.gumbo_tag_from_original_text(text voidptr)
fn C.gumbo_normalize_svg_tagname(tagname voidptr) &char
fn C.gumbo_tag_enum(tagname &char) int
fn C.gumbo_tagn_enum(tagname &char, length u32) int
fn C.gumbo_get_attribute(attrs voidptr, name &char) voidptr

fn gumbo_cstr(p &char) string {
	if isnil(p) {
		return ''
	}
	return unsafe { tos_clone(&u8(p)) }
}

pub fn gumbo_libok() bool {
	return C.gumbo_libok() != 0
}

pub fn gumbo_dyn_init(path string) int {
	return C.gumbo_dyn_init(path.str)
}

pub fn gumbo_has_symbol(name string) bool {
	return C.gumbo_dyn_has_symbol(name.str) != 0
}

pub fn gumbo_cleanup() {
	C.gumbo_dyn_cleanup()
}

pub fn gumbo_default_options() voidptr {
	return C.gumbo_dyn_default_options()
}

pub fn gumbo_parse(html string) !voidptr {
	out := C.gumbo_parse(html.str)
	if isnil(out) {
		return error('gumbo_parse 失败')
	}
	return out
}

pub fn gumbo_parse_with_options(options voidptr, html string) !voidptr {
	out := C.gumbo_parse_with_options(options, html.str, html.len)
	if isnil(out) {
		return error('gumbo_parse_with_options 失败')
	}
	return out
}

pub fn gumbo_destroy(out voidptr) {
	if isnil(out) {
		return
	}
	C.gumbo_destroy_output(gumbo_default_options(), out)
}

pub fn gumbo_tag_enum(name string) int {
	return C.gumbo_tag_enum(name.str)
}

pub fn gumbo_tag_is_void(tag int) bool {
	return C.gumbo_tag_is_void(tag)
}

pub fn gumbo_normalized_tagname(tag int) string {
	return gumbo_cstr(C.gumbo_normalized_tagname(tag))
}
