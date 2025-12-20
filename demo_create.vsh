import vcp
import touse.xml
import mkuse.feedut

fn create_xmldoc() {
    o := xml.parse_string("<bookmark>hhh</bookmark>")
    dump(o)
    // o2 := xml.parse_string('<outline text="" title="" type="rss" xmlUrl="></outline>')
    // dump(o2)
    // dump(o2.child_at(0).attrs)
    // o.children.add(o2.child_at(0))
    
    n3 := xml.Node.new(o, "outline", "hehhee")
    n3.attrs.add(xml.Attr.new("text", "itt中ext"))
    n3.attrs.add(xml.Attr.new("type", "rss"))
    n3.attrs.add(xml.Attr.new("xmlUrl", "https://ccc"))
    s := o.serialize()
    dump(s)
    
    o.free()
}

fn create_opmldoc() {
    op := feedut.Opml.new('demooo')
    op.add('text111', 'title111', 'bookmark111', 'https://111')
    dump(op.dump(true))

    op.save('hehhe.opml') or {vcp.error(err.str())}

    assert op.count()==1
    assert op.remove(5) == false
    assert op.remove(0) == true
    assert op.count()==0
    
    op.set_title('demo222')
    assert op.title() == 'demo222'
    dump(op.dump(true))
    
    // op.save('hehhe.opml') or {vcp.error(err.str())}
}

create_xmldoc()
create_opmldoc()
