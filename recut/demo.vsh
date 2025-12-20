import vcp
import touse.recut
import touse.ffi

struct Foo{}

fn demo_ffi_util() {
    rv := int(0)
    rp := vnil
    
    rv = ffi.ffity_oftmpl(0)
        vcp.info(rv, ffi.get_type_obj3(rv))
    rv = ffi.ffity_oftmpl(usize(0))
        vcp.info(rv, ffi.get_type_obj3(rv))
    rv = ffi.ffity_oftmpl(&Foo{})
        vcp.info(rv, ffi.get_type_obj3(rv))
    rv = ffi.ffity_oftmpl(charptr(0))
        vcp.info(rv, ffi.get_type_obj3(rv))
    rv = ffi.ffity_oftmpl(f32(0))
        vcp.info(rv, ffi.get_type_obj3(rv))
    rv = ffi.ffity_oftmpl(true)
        vcp.info(rv, ffi.get_type_obj3(rv))
    
    slen := ffi.callfca8('strlen', 0, c'abc', 0)
    vcp.info(slen)
    assert(slen==3)
}
    
recut.init_()
    
    set := recut.new()
    vcp.info(set)
    assert set!=vnil
    
    set2 := set.dup()
    vcp.info(set2)
    assert set2!=vnil
    
     // not regi
    assert set.type_p(3) == false
    
    tyval := set.register_type("integer123")
    vcp.info(tyval)
    
    assert set.type_p(tyval) == true
    
    assert set.count(tyval) == 0
    
    set.destroy()
    
    // recut.fini()

    demo_ffi_util()
