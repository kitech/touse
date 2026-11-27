// ABI 镜像 + 高层访问：字段顺序严格对齐 gumbo.h。
// 这里用 V 本地结构（不是 struct C.x），由 V 生成 C 定义；C 源文件仍 include 真头，
// 两边是不同编译单元，只要字段顺序和大小一致即可。
module htmpar

struct GumboSourcePosition {
	line   u32
	column u32
	offset u32
}

struct GumboStringPiece {
	data   &char
	length usize
}

struct GumboVector {
	data     voidptr
	length   u32
	capacity u32
}

struct GumboAttribute {
	attr_namespace int
	name           &char
	original_name  GumboStringPiece
	value          &char
	original_value GumboStringPiece
	name_start     GumboSourcePosition
	name_end       GumboSourcePosition
	value_start    GumboSourcePosition
	value_end      GumboSourcePosition
}

struct GumboDocument {
	children             GumboVector
	has_doctype          u8
	name                 &char
	public_identifier    &char
	system_identifier    &char
	doc_type_quirks_mode int
}

struct GumboText {
	text          &char
	original_text GumboStringPiece
	start_pos     GumboSourcePosition
}

struct GumboElement {
	children         GumboVector
	tag              int
	tag_namespace    int
	original_tag     GumboStringPiece
	original_end_tag GumboStringPiece
	start_pos        GumboSourcePosition
	end_pos          GumboSourcePosition
	attributes       GumboVector
}

union GumboNodeV {
	document GumboDocument
	element  GumboElement
	text     GumboText
}

struct GumboInternalNode {
	type                int
	parent              &GumboInternalNode
	index_within_parent usize
	parse_flags         int
	v                   GumboNodeV
}

pub type GumboNode = GumboInternalNode

struct GumboOutput {
	document &GumboInternalNode
	root     &GumboInternalNode
	errors   GumboVector
}

pub fn gumbo_output(out voidptr) &GumboOutput {
	if isnil(out) {
		panic('gumbo output is nil')
	}
	return &GumboOutput(out)
}

pub fn gumbo_root(out voidptr) ?&GumboInternalNode {
	n := gumbo_output(out).root
	if isnil(n) {
		return none
	}
	return n
}

pub fn gumbo_document(out voidptr) ?&GumboInternalNode {
	n := gumbo_output(out).document
	if isnil(n) {
		return none
	}
	return n
}

pub fn gumbo_node_type(node &GumboInternalNode) int {
	return node.type
}

pub fn gumbo_node_children(node &GumboInternalNode) []&GumboInternalNode {
	vec := match node.type {
		0 { node.v.document.children }
		1, 7 { node.v.element.children }
		else { return []&GumboInternalNode{} }
	}
	mut out := []&GumboInternalNode{cap: int(vec.length)}
	mut ptr := &voidptr(vec.data)
	for i := 0; i < int(vec.length); i++ {
		out << &GumboInternalNode(ptr[i])
	}
	return out
}

pub fn gumbo_node_tag(node &GumboInternalNode) int {
	if node.type == 1 || node.type == 7 {
		return node.v.element.tag
	}
	return -1
}

pub fn gumbo_node_text(node &GumboInternalNode) string {
	if node.type == 2 || node.type == 3 || node.type == 4 || node.type == 5 {
		return gumbo_cstr(node.v.text.text)
	}
	return ''
}

pub fn gumbo_node_attr(node &GumboInternalNode, name string) string {
	if node.type != 1 && node.type != 7 {
		return ''
	}
	a := C.gumbo_get_attribute(voidptr(&node.v.element.attributes), name.str)
	if isnil(a) {
		return ''
	}
	return gumbo_cstr((&GumboAttribute(a)).value)
}

// 类方法层：把上面的自由函数包成 receiver 方法，调用方式和 lexbor 一致。
// 名字带 Gumbo 前缀，避开同模块里 lexbor 已占用的 Document / Node。
pub struct GumboDoc {
	ptr voidptr // GumboOutput*
}

pub struct GumboNodeRef {
	ptr &GumboInternalNode
}

pub fn gumbo_new_document(html string) !GumboDoc {
	ptr := gumbo_parse(html) or { return err }
	return GumboDoc{ptr: ptr}
}

pub fn (d &GumboDoc) free() {
	if !isnil(d.ptr) {
		gumbo_destroy(d.ptr)
		d.ptr = nil
	}
}

pub fn (d GumboDoc) document() GumboNodeRef {
	n := gumbo_document(d.ptr) or { return GumboNodeRef{ptr: nil} }
	return GumboNodeRef{ptr: n}
}

pub fn (d GumboDoc) root() GumboNodeRef {
	n := gumbo_root(d.ptr) or { return GumboNodeRef{ptr: nil} }
	return GumboNodeRef{ptr: n}
}

pub fn (n GumboNodeRef) is_nil() bool {
	return isnil(n.ptr)
}

pub fn (n GumboNodeRef) type_id() int {
	if n.is_nil() {
		return -1
	}
	return gumbo_node_type(n.ptr)
}

pub fn (n GumboNodeRef) children() []GumboNodeRef {
	if n.is_nil() {
		return []GumboNodeRef{}
	}
	mut out := []GumboNodeRef{}
	for c in gumbo_node_children(n.ptr) {
		out << GumboNodeRef{ptr: c}
	}
	return out
}

pub fn (n GumboNodeRef) tag() int {
	if n.is_nil() {
		return -1
	}
	return gumbo_node_tag(n.ptr)
}

pub fn (n GumboNodeRef) tag_name() string {
	t := n.tag()
	if t < 0 {
		return ''
	}
	return gumbo_normalized_tagname(t)
}

pub fn (n GumboNodeRef) text() string {
	if n.is_nil() {
		return ''
	}
	return gumbo_node_text(n.ptr)
}

pub fn (n GumboNodeRef) attr(name string) string {
	if n.is_nil() {
		return ''
	}
	return gumbo_node_attr(n.ptr, name)
}
