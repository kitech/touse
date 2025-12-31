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
    

fn demo_mset() {
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
}

fn demo_db() ! {
    db := recut.DB.new()
    db.int_check() !
    db.insert('Zero', 0) !

    rec := recut.Record.new()
    rec.set_source('cmdli')
    rec.set_location(0)
    fld := recut.Field.new('Foo', 'bar')
    rec.mset().append(recut.Type(1), fld.vptr())
    
    dump(rec.source())
    dump(rec.num_fields())
    dump(rec.location_str())

    db.int_check() !
    db.insert('Note', rec) !
    db.int_check() !

    wrs := recut.Writer.new()
    // wrs.write_str() !
    // wrs.write_field(fld) !
    // println("ff")
    // wrs.write_record(rec) !
    println("======== db dump...")
    wrs.write_db(db) !
    println("======== db dump done")
    // dump(recut.wrbuf.tosdup())
}

recut.init_()
demo_ffi_util()
demo_mset()
demo_db() or { panic(err) }
