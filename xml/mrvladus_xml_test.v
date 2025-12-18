module xml

fn test_1() {}

fn test_invalid_str() {
    
    node := parse_string('{123foo}')
    defer {node.free()}
    // assert node==vnil
    // dump(node)
    // dump(node.attrs)
    // dump(node.children.data())
    assert node.children.len == 0
    assert node.attrs.len == 0
    assert node.empty()
}
fn test_simstr() {
    
    node := parse_string('<123foo/>')
    defer {node.free()}
    // assert node==vnil
    // dump(node)
    // dump(node.attrs)
    dump(node.children.data[voidptr]())
    for d in node.children.data[XMLAttr]() {
        dump(d)
    }
    assert node.children.len == 1
    assert node.attrs.len == 0
    // assert !node.empty()
}

fn test_list_add_del() {
    l := XMLList.new()
    l.add(voidptr(1))
    assert l.len == 1
    l.del(0)
    assert l.len == 0
    l.free()
    
    l = XMLList.new()
    for i in 0..9 {
        l.add(voidptr(i+1))
        // dump("$i, ${l.len}")
    }
    assert l.len == 9
    
    l.del(3)
    assert l.len == 8
    for i in 0..l.len {
        // dump(l.data[i])
    }
    
    l.free()
}
