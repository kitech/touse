// module bdb
import bdb
import time

fn test_1() {
    dump(sizeof(bdb.DB))
    dump(sizeof(bdb.DBT))
    dump(sizeof(bdb.DBC))
}


fn test_open_close() ! {
    db := bdb.DB.create0(0)
    // db.closex(0)
    db.openx("demo.db", bdb.BTREE, 0) !
    btime := time.now()
    db.putx('abc', '123.'.repeat(23)) !
    dump(time.since(btime))

    btime = time.now()
    s := ''
    for i in 0..9999 {
        s = db.getx('abc') !
    }
    dump(time.since(btime))
    assert s.len == '123.'.repeat(23).len
    assert s == '123.'.repeat(23)

    ok := db.has('abc') !
    assert ok
    db.delx('abc') !
    ok = db.has('abc') !
    assert ok==false
    
    db.closex(0)
}

fn test_iter() ! {
    db := bdb.DB.create0(0)
    db.openx("demo.db", bdb.BTREE, 0) !
    defer { db.closex(0) }
    
    cnt := db.count_byiter() !
    dump(cnt)
    cnt = db.count_byrecno() !
    dump(cnt)

    db.putx('abc'.repeat(2), '123.'.repeat(5)) !
    db.putx('ddd'.repeat(2), '555.'.repeat(5)) !
    db.putx('eee'.repeat(2), '555.'.repeat(5)) !
    db.delx('ddd'.repeat(2)) !
    cnt = db.count_byrecno() !
    assert cnt == 2
    
    c := db.cursorx() !
    defer { c.closex() }
    for c.next(false) ! {
        rno := c.get_recno() !
        assert rno > 0
        k, v := c.get_kv() !
        dump('$rno $k $v')
    }

    {
        rno := db.get_recno('eee'.repeat(2)) !
        assert rno > 0
        k, v := db.get_kv(rno) !
        // dump('$rno $k $v')
        assert v.len == '555.'.repeat(5).len
        assert v == '555.'.repeat(5)
    }
    
}
