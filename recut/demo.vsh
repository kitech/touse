import touse.recut

recut.init_()
    
    set := recut.new()
    dump(set)
    assert set!=vnil
    
    set2 := set.dup()
    dump(set2)
    assert set2!=vnil
    
    bv := set.type_p(3) // not regi
    assert bv == false
    
    tyval := set.register_type("integer123")
    dump(tyval)
    
    assert set.type_p(tyval) == true
    
    nv := set.count(tyval)
    assert nv==0
    
    set.destroy()
    
    // recut.fini()
