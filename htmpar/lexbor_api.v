// typed 高层封装：lexbor 结构体本来就不透明，只包 voidptr 和输出参数转换结果。
module htmpar

pub struct Document {
	ptr voidptr
}

pub struct Node {
	ptr voidptr
}

pub fn lexbor_new_document() ?Document {
	p := lexbor_document_create() or { return none }
	return Document{p}
}

pub fn (d &Document) free() {
	if !isnil(d.ptr) {
		lexbor_document_destroy(d.ptr)
	}
}

pub fn (d Document) parse(html string) bool {
	return lexbor_document_parse(d.ptr, html)
}

pub fn (d Document) title() string {
	return lexbor_document_title(d.ptr)
}

pub fn (d Document) body() Node {
	return Node{lexbor_body(d.ptr)}
}

pub fn (n Node) is_nil() bool {
	return isnil(n.ptr)
}

pub fn (n Node) name() string {
	return lexbor_node_name(n.ptr)
}

pub fn (n Node) text() string {
	return lexbor_text_content(n.ptr)
}

pub fn (n Node) tag_name() string {
	return lexbor_element_tag_name(n.ptr)
}

pub fn (n Node) local_name() string {
	return lexbor_element_local_name(n.ptr)
}

pub fn (n Node) attr(name string) string {
	return lexbor_element_get_attribute(n.ptr, name)
}

pub fn (n Node) first_child() Node {
	return Node{lexbor_first_child(n.ptr)}
}

pub fn (n Node) next() Node {
	return Node{lexbor_next(n.ptr)}
}

pub fn (n Node) parent() Node {
	return Node{lexbor_parent(n.ptr)}
}

pub fn (n Node) type_id() u32 {
	return lexbor_node_type(n.ptr)
}
