module xml

#flag -I@DIR/
#include "xmlc.h"
#flag @DIR/xmlc.o

pub type XMLDoc = C.xml_document
pub struct C.xml_document{}
pub type XMLNode2 = C.xml_node
pub struct C.xml_node{}
pub type XMLAttr2 = C.xml_attribute
pub struct C.xml_attribute{}
pub type XMLStr = C.xml_string
pub struct C.xml_string{}


pub fn C.xml_parse_document(buf charptr, len usize) &XMLDoc
pub fn parse_document(buf string) &XMLDoc {
    return C.xml_parse_document(buf.str, buf.len)
}
pub fn C.xml_document_free(voidptr, bool)
pub fn (doc &XMLDoc) free() {
    C.xml_document_free(doc, false)
}

pub fn C.xml_document_root(...voidptr) &XMLNode2
pub fn (doc &XMLDoc) root() &XMLNode2 {
    return C.xml_document_root(doc)
}

pub fn C.xml_node_name(voidptr) &XMLStr
pub fn C.xml_easy_name(voidptr) charptr
pub fn (node &XMLNode2) name() string {
    rv := C.xml_easy_name(node).tosfree()
    return rv
}

pub fn C.xml_node_content(voidptr) &XMLStr
pub fn (node &XMLNode2) content() string {
    rv := C.xml_node_content(node)
    return rv.str()
}

pub fn C.xml_node_children(voidptr) usize
pub fn (node &XMLNode2) children() int {
    return int(C.xml_node_children(node))
}
pub fn C.xml_node_child(voidptr, usize) &XMLNode2
pub fn (node &XMLNode2) child(idx int) &XMLNode2 {
    return C.xml_node_child(node, usize(idx))
}

pub fn C.xml_node_attributes(voidptr) usize
pub fn (node &XMLNode2) attributes() int {
    return int(C.xml_node_attributes(node))
}
pub fn C.xml_node_attribute_name(voidptr, usize) &XMLStr
pub fn (node &XMLNode2) attr_name(idx int) string {
    rv := C.xml_node_attribute_name(node, usize(idx))
    return rv.str()
}
pub fn C.xml_node_attribute_content(voidptr, usize) &XMLStr
pub fn (node &XMLNode2) value(idx int) string {
    rv := C.xml_node_attribute_content(node, usize(idx))
    return rv.str() 
}

fn C.xml_string_length(voidptr) usize
fn C.xml_string_copy(...voidptr)
pub fn (s &XMLStr) str() string {
    len := C.xml_string_length(s)
    buf := [len+1]i8{}
    C.xml_string_copy(s, &buf[0], len)
    return charptr(&buf[0]).tosdup()
}
