module feedut

import os
import time
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
    
    // extended
    ctime string
}

pub struct Opml {
pub mut:
    doc &xml.Node = vnil
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
    s := n.serialize()
    if s.contains('></outline ') {
        dump(n)
        dump(n.at(0))
        vcp.error("parser errored", s)
    }
    
    assert n.tag() == 'documentRoot'
    assert n.count()==1 // opml child

    op := &Opml{}
    op.doc = n
    op.root = n.at(0)
    op.head = op.root.at(0)
    op.body = op.root.at(1)
    
        assert op.root.tag() == 'opml'
        assert op.root.count()>0
        assert op.root.at(0).tag() == 'head'
        assert op.root.at(1).tag() == 'body'
        
    
    return op
}

pub fn Opml.new(title string) &Opml {
    op := &Opml{}
    // op.doc = xml.Node.new(vnil, '', '')
    op.root = xml.Node.new_root('opml')
    op.root.add_attr('version', "1.0")
    
    op.head = op.root.add_elem('head')
    op.head.add_elem('title')
    
    op.body = op.root.add_elem('body')
    return op
}
pub fn (op &Opml) save(file string) ! {
    scc := op.dump(true)
    os.write_file(file, scc) !
}
// todo reformat with indent
pub fn (op &Opml) dump(refmt bool) string {
    n := if op.doc==vnil{op.root} else {op.doc}
    res := n.serialize()
    if !res.starts_with(xml.header) {
        res = xml.header + "\n" + res
    } 
    // res = op.reformat(res)
    vcp.info(res.len, res, res.len)
    return res
}

fn (op &Opml) reformat(s string) string {
    res := s
    res = res.replace('><head>', '>\n  <head>')
    res = res.replace('></head>', '>\n  </head>')
    res = res.replace('><title>', '>\n    <title>')
    res = res.replace('><body>', '>\n  <body>')
    res = res.replace('><outline ', '>\n    <outline ')
    res = res.replace('></body>', '>\n  </body>')
    res = res.replace('></opml>', '>\n</opml>')
    return res
}

pub fn (op &Opml) add(text string, title string, typ string, url string) bool {
    n := op.body.add_elem('outline')

    n.add_attr('text', text)
    n.add_attr('title', title)
    n.add_attr('type', typ)
    n.add_attr('xmlUrl', url)
    
    n.add_attr('ctime', time.now().str())

    return true
}

pub fn (op &Opml) remove(idx int) bool {
    if idx >= 0 && idx < op.count() {
        op.body.at(idx).del()
        return true
    }
    return false
}

pub fn (op &Opml) count() int {
    return op.body.count()
}

pub fn (op &Opml) find_byurl(url string) int {
    count := op.count()
    for i in 0..count {
        n := op.body.at(i)
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
        n := op.body.at(i)
        text := n.attr('text')
        title := n.attr('title')
        if text.contains(keyword) || title.contains(keyword) {
            res << i
        }
    }
    
    return res
}

pub fn (op &Opml) set_title(title string) {
    op.head.add_elem('title').add_text(title)
    op.head.at(0).del()
}
pub fn (op &Opml) title() string {
    return op.head.at(0).content()
}
