module xml

import os
import vcp
import vcp.ircpp
import vcp.venv
import touse.ffi

// libroxml-3.0.2-76e6f42
// cmake ../ -DCMAKE_INSTALL_PREFIX:PATH=/opt/devsys -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DBUILD_TESTING=off

$if prod || prodrc ? {
    // this module use function_missing feat, cannot static link
    // because there is no roxml's function linked at link time
    // -Wl,--whole-archive maybe working, but V cannot properly process it
    #flag -lroxml
    // #flag -Wl,--whole-archive
    // #flag /opt/devsys/lib/libroxml.a
    // #flag -Wl,--no-whole-archive
    // gcc
    // #flag -l:libroxml.a
} $else {
    #flag -lroxml
}


#include "roxml.h"

pub type Node = C.node
// @[typedef]
pub struct C.node {
    pub mut:
    type u16
    attr &Node = vnil
}
@[markused]
pub fn (node &Node) str() string {
    _ = Anyer(&Node(vnil))
    return '&${@MOD}__${@STRUCT}(0x${voidptr(node)})'
}

pub enum NodeType {
    elm = C.ROXML_ELM_NODE
    attr = C.ROXML_ATTR_NODE
    cmt = C.ROXML_CMT_NODE
    txt = C.ROXML_TXT_NODE
    ns = C.ROXML_NS_NODE 
}

pub union Retval {
    ircpp.CRetval
    node &Node = vnil
}

fn function_missing(fnname string, args ...Anyer) Retval {
    if !fnname.starts_with('roxml_') {
        vcp.warn('invalid fnname, must prefix roxml_', fnname)
    }
    // vcp.info(fnname, args.str())
    return ffi.callany[Retval](fnname, ...args)
}


pub fn parse_file(file string) &Node { return roxml_file(file) }

pub fn roxml_file(file string) &Node {
    scc := os.read_file(file) or {panic(err)}
    return roxml_load_buf(charptr(scc.str)).node
}
pub fn (node &Node) close() {
    roxml_close(node)
}

pub fn (node &Node) serialize() string { return node.commit_buffer() }

pub fn (node &Node) commit_buffer() string {
    buf := charptr(vnil)
    len := roxml_commit_buffer(node, voidptr(&buf), 1).int
    // vcp.info(len, buf.tosref())
    
    return buf.tosfree()
}

pub fn (node &Node) add_elem(name string) &Node {
    return node.add(.elm, name, '')
}
pub fn (node &Node) add_attr(name string, value string) &Node {
    return node.add(.attr, name, value)
}
pub fn (node &Node) add_text(value string) &Node {
    return node.add(.txt, '', value)
}
pub fn (node &Node) add(typ NodeType, name string, value string) &Node {
    rv := roxml_add_node(node, 0, int(typ), charptr(name.str), charptr(value.str)).node
    return rv
}
pub fn Node.new_root(name string) &Node {
    rv := roxml_add_node(vnil, 0, int(NodeType.elm), charptr(name.str), charptr(vnil)).node
    return rv    
}

pub fn (node &Node) del() {
    roxml_del_node(node)
}
pub fn (node &Node) del_attr(key string) {
    n := roxml_get_attr(node, charptr(key.str), 0).node
    n.del()
}

pub fn (node &Node) count() int { return node.chld_nb() }
pub fn (node &Node) chld_nb() int {
    return roxml_get_chld_nb(node).int
}
pub fn (node &Node) at(idx int) &Node { return node.chld(idx) }
pub fn (node &Node) chld(idx int) &Node {
    return roxml_get_chld(node, vnil, idx).node
}

pub fn (node &Node) attr_count() int { return node.attr_nb() }
pub fn (node &Node) attr_nb() int {
    return roxml_get_attr_nb(node).int
}
pub fn (node &Node) attr(key string) string {
    n := roxml_get_attr(node, charptr(key.str), 0).node
    return n.content()
}

pub fn (node &Node) type() NodeType {
    rv := roxml_get_type(node).int
    return NodeType(rv)
}

pub fn (node &Node) tag() string { return node.name() }

pub fn (node &Node) name() string {
    return roxml_get_name(node, vnil, 0).cptr.tosfree()
}
pub fn (node &Node) content() string {
    return roxml_get_content(node, vnil, 0, vnil).cptr.tosfree()
}
