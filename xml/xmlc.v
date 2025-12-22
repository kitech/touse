module xml

#flag -I@DIR/
#include "xmlc.h"
#flag @DIR/xmlc.o

pub type Doc = C.xml_document
pub struct C.xml_document{}
pub type Node2 = C.xml_node
pub struct C.xml_node{}
pub type Attr2 = C.xml_attribute
pub struct C.xml_attribute{}
pub type Str = C.xml_string
pub struct C.xml_string{}

pub fn (node &Node2) str() string {
    return "&${@MOD}.${@STRUCT}(${voidptr(node)})"
}

pub fn C.xml_parse_document(buf charptr, len usize) &Doc
pub fn parse_document(buf string) &Doc {
    return C.xml_parse_document(buf.str, buf.len)
}
pub fn C.xml_document_free(voidptr, bool)
pub fn (doc &Doc) free() {
    C.xml_document_free(doc, false)
}

pub fn C.xml_document_root(...voidptr) &Node2
pub fn (doc &Doc) root() &Node2 {
    return C.xml_document_root(doc)
}

pub fn C.xml_node_name(voidptr) &Str
pub fn C.xml_easy_name(voidptr) charptr
pub fn (node &Node2) name() string {
    rv := C.xml_easy_name(node).tosfree()
    return rv
}

pub fn C.xml_node_content(voidptr) &Str
pub fn (node &Node2) content() string {
    rv := C.xml_node_content(node)
    return rv.str()
}

pub fn C.xml_node_children(voidptr) usize
pub fn (node &Node2) count() int {
    return int(C.xml_node_children(node))
}
pub fn C.xml_node_child(voidptr, usize) &Node2
pub fn (node &Node2) at(idx int) &Node2 {
    return C.xml_node_child(node, usize(idx))
}

pub fn C.xml_node_attributes(voidptr) usize
pub fn (node &Node2) attr_count() int {
    return int(C.xml_node_attributes(node))
}
pub fn C.xml_node_attribute_name(voidptr, usize) &Str
pub fn (node &Node2) attr_name(idx int) string {
    rv := C.xml_node_attribute_name(node, usize(idx))
    return rv.str()
}
pub fn C.xml_node_attribute_content(voidptr, usize) &Str
pub fn (node &Node2) attr_value(idx int) string {
    rv := C.xml_node_attribute_content(node, usize(idx))
    return rv.str() 
}

fn C.xml_string_length(voidptr) usize
fn C.xml_string_copy(...voidptr)
pub fn (s &Str) str() string {
    len := C.xml_string_length(s)
    buf := [len+1]i8{}
    C.xml_string_copy(s, &buf[0], len)
    return charptr(&buf[0]).tosdup()
}
