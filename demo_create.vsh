import vcp
import touse.xml
import mkuse.feedut

fn create_xmldoc() {
    // <?xml version="1.0" encoding="UTF-8"?>
    o := xml.parse_document('<items><item><name title="日本語">日本語</name><description>これはテストです</description></item><item><name text="中文">中文</name><description>这是一个测试</description></item></items>')
    dump(o)
    
    root := o.root()
    dump(root.name())
    
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
fn parse_cjkxml() {
    o := feedut.opml_file('../xpimerge/xpibmrss.opml')
    assert o!= vnil
}

create_xmldoc()
create_opmldoc()
parse_cjkxml()
