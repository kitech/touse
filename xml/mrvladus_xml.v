module xml

import arrays

#flag -I@DIR/
// Must be defined before including xml.h in ONE source file
#flag -D XML_H_IMPLEMENTATION
#include "mrvladus_xml.h"


pub type XMLNode = C.XMLNode
// The main object to interact with parsed XML nodes. Represents single XML tag.
@[typedef]
pub struct C.XMLNode {
pub mut:
  tag charptr // char *tag;         // Tag string.
  text charptr // char *text;        // Inner text of the tag. NULL if tag has no inner text.
  attrs &XMLList // XMLList *attrs;    // List of tag attributes. Check "node->attrs->len" if it has items.
  parent &XMLNode // XMLNode *parent;   // Node's parent node. NULL for the root node.
  children &XMLList // XMLList *children; // List of tag's sub-tags. Check "node->children->len" if it has items.
}
pub fn (node &XMLNode) tag() string{ return node.tag.tosref() }
pub fn (node &XMLNode) text() string{ return node.text.tosref() }

pub type XMLAttr = C.XMLAttr
// Tags attribute containing key and value.
// Like: <tag foo_attr="foo_value" bar_attr="bar_value" />
@[typedef]
pub struct C.XMLAttr {
  key charptr // char *key;
  value charptr // char *value;
}

pub fn (node &XMLAttr) key() string{ return node.key.tosref() }
pub fn (node &XMLAttr) value() string{ return node.value.tosref() }


pub type XMLList = C.XMLList
// Simple dynamic list that only can grow in size.
// Used in XMLNode for list of children and list of tag attributes.
@[typedef]
pub struct C.XMLList {
  len usize // size_t len;  // Length of the list.
  size usize // size_t size; // Capacity of the list in bytes.
  // data &&XMLNode // void **data; // List of pointers to list items.
  data &voidptr // void **data; // List of pointers to list items.
}
// XMLNode/XMLAttr
pub fn (l &XMLList) data[T]() []&T {
    return carr2varr[&T](l.data, int(l.len))
    // return arrays.carray_to_varray[voidptr](l.data, int(l.len))
}
pub fn XMLList.new() &XMLList {
    return C.xml_list_new()
}
pub fn (l &XMLList) add(data voidptr) {
    assert data != vnil
    C.xml_list_add(l, data)
}
pub fn (l &XMLList) del(idx usize) {
    c99 {
        XMLList* list = l;
        usize oldlen = list->len;
        void* oldval = list->data[idx];
        for (int i = idx; i < oldlen; i++) {
            if (i==0) {}
            else{list->data[i-1]=list->data[i];}
        }
        list->data[oldlen-1] = 0;
        list->len --;
    }
}
pub fn (l &XMLList) free() {
    c99 {
        free(l->data);
        free(l);
    }
}

pub fn parse_string(xml_ string) &XMLNode {
    return C.xml_parse_string(xml_.str)
}
pub fn parse_file(path string) &XMLNode {
    return C.xml_parse_file(path.str)
}

pub fn (node &XMLNode) free()  { C.xml_node_free(node) }
pub fn (node &XMLNode) empty() bool { 
    return node.tag == vnil
}

pub fn (node &XMLNode) child_at(idx usize) &XMLNode {
    return C.xml_node_child_at(node, idx)
}
pub fn (node &XMLNode) find_by_path(path string, exact bool) &XMLNode {
    return C.xml_node_find_by_path(node, path.str, exact)
}
pub fn (node &XMLNode) find_tag(tag string, exact bool) &XMLNode {
    return C.xml_node_find_tag(node, tag.str, exact)
}
pub fn (node &XMLNode) attr(attr_key string) string {
    return C.xml_node_attr(node, attr_key.str).tosdup()
}

pub fn (node &XMLNode) serialize() string {
    str := C.xml_string_new()
    C.xml_node_serialize(node, str)
    res := str.str.tosdup()
    C.xml_string_free(str)
    return res
}

// Parse XML string and return root XMLNode.
// Returns NULL for error.
// XML_H_API XMLNode *xml_parse_string(const char *xml);
pub fn C.xml_parse_string(xml charptr) &XMLNode
// Parse XML file for given path and return root XMLNode.
// Returns NULL for error.
// XML_H_API XMLNode *xml_parse_file(const char *path);
pub fn C.xml_parse_file(path charptr) &XMLNode
// Get child of the node at index.
// Returns NULL if not found.
// XML_H_API XMLNode *xml_node_child_at(XMLNode *node, size_t idx);
pub fn C.xml_node_child_at(node &XMLNode, idx usize) &XMLNode
// Find xml tag by path like "div/p/href"
// XML_H_API XMLNode *xml_node_find_by_path(XMLNode *root, const char *path, bool exact);
pub fn C.xml_node_find_by_path(root &XMLNode, path charptr, exact bool) &XMLNode
// Get first matching tag in the tree.
// If exact is "false" - will return first tag which name contains "tag"
// XML_H_API XMLNode *xml_node_find_tag(XMLNode *node, const char *tag, bool exact);
pub fn C.xml_node_find_tag(node &XMLNode, tag charptr, exact bool) &XMLNode
// Get value of the tag attribute.
// Returns NULL if not found.
// XML_H_API const char *xml_node_attr(XMLNode *node, const char *attr_key);
pub fn C.xml_node_attr(node &XMLNode, attr_key charptr) charptr
// Serialize `XMLNode` into `XMLString`.
// XML_H_API void xml_node_serialize(XMLNode *node, XMLString *str);
pub fn C.xml_node_serialize(node &XMLNode, str &XMLString);
// Cleanup node and all it's children.
// XML_H_API void xml_node_free(XMLNode *node);
pub fn C.xml_node_free(node &XMLNode)

pub fn C.xml_list_new() &XMLList
pub fn C.xml_list_add(l &XMLList, data voidptr)

// XML_H_API XMLString *xml_string_new();
pub fn C.xml_string_new()  &XMLString
// Append string to the end of the `XMLString`.
// XML_H_API void xml_string_append(XMLString *str, const char *append);
pub fn C.xml_string_append(str &XMLString, append charptr);
// Free `XMLString`.
// XML_H_API void xml_string_free(XMLString *str);
pub fn C.xml_string_free(str &XMLString)

pub type XMLString = C.XMLString
@[typedef]
pub struct C.XMLString {
pub mut:
    len usize 
    size usize 
    str charptr
}
