module feedut

import os
import vcp
import touse.xml

@[markused]
pub struct OpmlKeyword {
    __global:
    opml string = 'opml'
    outline string = 'outline'
    head string = 'head'
    body string = 'body'
    
    // attrs
    text string = 'text'
    title string = 'title'
    type string = 'type'
    url string = 'xmlUrl'
}

pub struct Opml {
pub mut:
    root &xml.Node = vnil
    head &xml.Node = vnil
    body &xml.Node = vnil
}

pub fn opml_parse(s string) &Opml {
    assert false, 'todo'
    return Opml.new('')
}

pub fn opml_file(file string) &Opml {
    n := xml.parse_file(file)
    assert n.tag() == 'opml'
    assert n.children.len==2
    assert n.child_at(0).tag() == 'head'
    assert n.child_at(1).tag() == 'body'

    op := &Opml{}
    op.root = n
    op.head = n.child_at(0)
    op.body = n.child_at(1)
    return op
}

pub fn Opml.new(title string) &Opml {
    op := &Opml{}
    op.root = xml.Node.new(vnil, 'opml', '')
    op.root.attrs.add(xml.Attr.new('version', "1.0"))
    
    op.head = xml.Node.new(op.root, 'head', '')
    xml.Node.new(op.head, 'title', title)
    
    op.body = xml.Node.new(op.root, 'body', '')
    
    return op
}
pub fn (op &Opml) save(file string) ! {
    scc := op.dump()
    os.write_file(file, scc) !
}
// todo reformat with indent
pub fn (op &Opml) dump() string {
    return xml.header + "\n" + op.root.serialize()
}

pub fn (op &Opml) add(text string, title string, typ string, url string) bool {
    n := xml.Node.new(op.body, 'outline', '')

    n.add_attr('text', text)
    n.add_attr('title', title)
    n.add_attr('type', typ)
    n.add_attr('xmlUrl', url)

    return true
}

pub fn (op &Opml) remove(idx int) bool {
    if idx >= 0 && idx < op.count() {
        op.body.children.del(idx.usize())
        return true
    }
    return false
}

pub fn (op &Opml) count() int {
    return op.body.children.len.int()
}

pub fn (op &Opml) find_byurl(url string) int {
    count := op.count()
    for i in 0..count {
        n := op.body.child_at(i)
        u := n.attr('xmlUrl')
        if u == url {
            return i
        }
    }
    return -1
}

pub fn (op &Opml) search(keyword string) []int {
    res := []int{}
    count := op.count()
    for i in 0..count {
        n := op.body.child_at(i)
        text := n.attr('text')
        title := n.attr('title')
        if text.contains(keyword) || title.contains(keyword) {
            res << i
        }
    }
    
    return res
}

pub fn (op &Opml) set_title(title string) {
    xml.Node.new(op.head, 'title', title)
    op.head.children.del(0)
}
pub fn (op &Opml) title() string {
    return op.head.child_at(0).text()
}
