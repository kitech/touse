// 动态加载入口：直接混编 lexbor_dyn.c，不生成 .o，不改 C 源。
module htmpar

import vcp.tcchf

// 这两个必须include一个，否则有可能导致非int返回值的函数错误的当int了
// #include <lexbor.h>
#include <@DIR/lexbor_dyn.c>
// #flag @DIR/lexbor_dyn.o

// include lexbor.h 原头，让 C 代码拿到真实函数原型，避免指针返回被隐式 int 截断。
fn C.lexbor_libok() int
fn C.lexbor_dyn_init(path &char) int
fn C.lexbor_dyn_cleanup()
fn C.lexbor_dyn_has_symbol(name &char) int

fn C.lxb_html_document_create() voidptr
fn C.lxb_html_document_destroy(doc voidptr) voidptr
fn C.lxb_html_document_parse(doc voidptr, html &u8, size usize) u32
fn C.lxb_html_document_title(doc voidptr, len &usize) &u8
fn C.lxb_html_document_body_element_noi(doc voidptr) voidptr
fn C.lxb_dom_node_first_child_noi(node voidptr) voidptr
fn C.lxb_dom_node_next_noi(node voidptr) voidptr
fn C.lxb_dom_node_parent_noi(node voidptr) voidptr
fn C.lxb_dom_node_type_noi(node voidptr) u32
fn C.lxb_dom_node_name(node voidptr, len &usize) &u8
fn C.lxb_dom_node_text_content(node voidptr, len &usize) &u8
fn C.lxb_dom_element_get_attribute(elem voidptr, name &u8, qn_len usize, value_len &usize) &u8
fn C.lxb_dom_element_tag_name(elem voidptr, len &usize) &u8
fn C.lxb_dom_element_local_name(elem voidptr, len &usize) &u8

fn lexbor_str(p &u8, len usize) string {
	if isnil(p) || len == 0 {
		return ''
	}
	return unsafe { p.vstring_with_len(int(len)).clone() }
}

pub fn lexbor_libok() bool {
	return C.lexbor_libok() != 0
}

pub fn lexbor_dyn_init(path string) int {
	return C.lexbor_dyn_init(path.str)
}

pub fn lexbor_has_symbol(name string) bool {
	return C.lexbor_dyn_has_symbol(name.str) != 0
}

pub fn lexbor_cleanup() {
	C.lexbor_dyn_cleanup()
}

pub fn lexbor_document_create() !voidptr {
	doc := C.lxb_html_document_create()
	if isnil(doc) {
		return error('lxb_html_document_create 失败')
	}
	return doc
}

pub fn lexbor_document_destroy(doc voidptr) {
	if !isnil(doc) {
		C.lxb_html_document_destroy(doc)
	}
}

pub fn lexbor_document_parse(doc voidptr, html string) bool {
	if isnil(doc) {
		return false
	}
	// LEXBOR_DYN_STATUS_OK == 0
	return C.lxb_html_document_parse(doc, &u8(html.str), html.len) == 0
}

pub fn lexbor_document_title(doc voidptr) string {
	mut len := usize(0)
	return lexbor_str(C.lxb_html_document_title(doc, &len), len)
}

pub fn lexbor_node_name(node voidptr) string {
	mut len := usize(0)
	return lexbor_str(C.lxb_dom_node_name(node, &len), len)
}

pub fn lexbor_text_content(node voidptr) string {
	mut len := usize(0)
	return lexbor_str(C.lxb_dom_node_text_content(node, &len), len)
}

pub fn lexbor_element_tag_name(elem voidptr) string {
	mut len := usize(0)
	return lexbor_str(C.lxb_dom_element_tag_name(elem, &len), len)
}

pub fn lexbor_element_local_name(elem voidptr) string {
	mut len := usize(0)
	return lexbor_str(C.lxb_dom_element_local_name(elem, &len), len)
}

pub fn lexbor_element_get_attribute(elem voidptr, name string) string {
	mut len := usize(0)
	p := C.lxb_dom_element_get_attribute(elem, &u8(name.str), name.len, &len)
	return lexbor_str(p, len)
}

pub fn lexbor_body(doc voidptr) voidptr {
	return C.lxb_html_document_body_element_noi(doc)
}

pub fn lexbor_first_child(node voidptr) voidptr {
	return C.lxb_dom_node_first_child_noi(node)
}

pub fn lexbor_next(node voidptr) voidptr {
	return C.lxb_dom_node_next_noi(node)
}

pub fn lexbor_parent(node voidptr) voidptr {
	return C.lxb_dom_node_parent_noi(node)
}

pub fn lexbor_node_type(node voidptr) u32 {
	return C.lxb_dom_node_type_noi(node)
}
