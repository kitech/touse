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
    assert !node.empty()
}
