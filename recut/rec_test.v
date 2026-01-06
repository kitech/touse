module recut

fn test_1() {}

fn test_2() {
    init_()
    
    set := Mset.new()
    dump(set)
    println(set)
    assert set!=vnil
    // set.destroy()
    
    set.destroy()
    fini()
}
