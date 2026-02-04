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

// if no all method works, only can use json

pub fn opml_file(file string) &Opml {
    return opml_file_xmlc_to_roxml(file)
    // return opml_file_nocjk_attr_value(file)
}

// since roxml parse CJK crash,
// use xmlc parse and copy to roxml
// !!! but xmlc cannot parse attr/content value with white space
pub fn opml_file_xmlc_to_roxml(file string) &Opml {
    scc := os.read_file(file) or {panic(err)}
    if scc.starts_with(xml.header) {
        scc = scc[xml.header.len..] // xmlc cannot parse xml header line
    }

    doc := xml.parse_document(scc)
    if doc==vnil { panic('parse failed') }
    defer { doc.free() }

    droot := doc.root()
    headnode := droot.at(0)
    bodynode := droot.at(1)
    // opml, head, body
    // vcp.info(droot.name(), headnode.name(), bodynode.name())
    assert droot.name() == 'opml'
    assert headnode.name() == 'head'
    assert bodynode.name() == 'body'
        
    titlenode := headnode.at(0)
    titlecc := titlenode.content()
    // vcp.info('title', titlecc)
    
    op := Opml.new(titlecc)
    
    for idx in 0..bodynode.count() {
        nn := bodynode.at(idx)
        text, title, typ, url, ctime := '', '', '', '', ''

        for j in 0..nn.attr_count() {
            aname := nn.attr_name(j)
            avalue := nn.attr_value(j)
            // vcp.info(idx.str(), j.str(), aname, avalue)
            
            match aname {
                'text' { text = avalue }
                'title' { title = avalue }
                'type' { typ = avalue }
                'xmlUrl' { url = avalue }
                'ctime' { ctime = avalue }
                else {}
            }
        }
        
        // vcp.info('adding', idx.str(), text, title, typ, url, ctime)
        op.add(text, title, typ, url, ctime)
    }

    return op
}

// wait and cannot use, until roxml support cjk...
pub fn opml_file_nocjk_attr_value(file string) &Opml {
    n := xml.parse_file(file)
    if n==vnil { return vnil }
    
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
    // vcp.info(res.len, res, res.len)
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

pub fn (op &Opml) add(text string, title string, typ string, url string, ctime string) bool {
    n := op.body.add_elem('outline')
    
    strfix := fn (s string) string { return s.replace(' ', '+') }

    n.add_attr('text', strfix(text))
    n.add_attr('title', strfix(title))
    n.add_attr('type', strfix(typ))
    n.add_attr('xmlUrl', strfix(url))
    
    if ctime!= "" {
        n.add_attr('ctime', strfix(ctime))
    }else{
        n.add_attr('ctime', strfix(time.now().str()))
    }
    
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

pub fn (op &Opml) geturl(idx int) string {
    n := op.body.at(idx)
    u := n.attr('xmlUrl')
    return u
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
