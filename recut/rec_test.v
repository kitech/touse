module recut

fn test_1() {}

fn test_2() {
    init_()
    
    set := new()
    dump(set)
    println(set)
    assert set!=vnil
    // set.destroy()
    
    fini()
}
