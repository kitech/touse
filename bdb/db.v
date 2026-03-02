module bdb

#flag -ldb
#include <db.h>


// api doc https://docs.oracle.com/database/bdb181/html/api_reference/C/frame_main.html

// key, value string saved with null

// write for v6.2

pub type ENV = C.DB_ENV
@[typedef]
pub struct C.DB_ENV {
    get_cache_max fn(&ENV, &u32, &u32) int
    set_cache_max fn(&ENV, u32, u32) int

    close   fn(&ENV, u32) int
    open    fn(&ENV, charptr, u32, int) int
    remove fn(&ENV, charptr, u32) int

    set_alloc fn(&ENV, voidptr, voidptr, voidptr) int
}

pub type DB = C.DB
@[typedef]
pub struct C.DB {
    close  fn(&DB, u32) int
    cursor fn(&DB, voidptr, &&DBC, u32) int
    del    fn(&DB, voidptr, &DBT, u32) int
    exists fn(&DB, voidptr, &DBT, u32) int
    get    fn(&DB, voidptr, &DBT, &DBT, u32) int
    put    fn(&DB, voidptr, &DBT, &DBT, u32) int
    open   fn(&DB, voidptr, charptr, charptr, int, u32, int) int

    set_flags fn(&DB, u32) int
    sync      fn(&DB, u32) int
    truncate  fn(&DB, voidptr, &u32, u32) int
    verify    fn(&DB, charptr, charptr, &C.FILE, u32) int

    get_cachesize fn(&DB, &u32, &u32, &int) int
    set_cachesize fn(&DB, u32, u32, int) int

    get_env  fn(&DB) &ENV
    set_alloc fn(&DB, voidptr, voidptr, voidptr) int
    
    pub:
}

pub type DBT = C.DBT
@[typedef]
pub struct C.DBT {
    pub:
    data voidptr
    size u32

    ulen u32
    dlen u32
    doff u32

    app_data voidptr
    flags u32
}

pub type DBC = C.DBC
@[typedef]
pub struct C.DBC {
    close fn(&DBC) int
    cmp   fn(&DBC, &DBC, &int, u32) int
    get   fn(&DBC, &DBT, &DBT, u32) int
    
    pub:
}


/////////////////

fn C.db_create(...voidptr) int

pub fn DB.create0(flags u32) &DB {
    return DB.create(nil, flags)
}
pub fn DB.create(env &ENV, flags u32) &DB {
    if env == nil {
        // env = ENV.getornew()
    }
    
    db := &DB(nil)
    rv := C.db_create(&db, env, flags)
    assert rv == 0, strerror(rv)
    assert db != nil

    if use_v_alloc {
        db.set_alloc(db, malloc, v_realloc, v_mem_free)
    }
    return db
}
const use_v_alloc = false
fn v_mem_free(p voidptr) {
    $if gcboehm ? {} $else { free() }
}

fn C.db_env_create(...voidptr) int
fn ENV.getornew() &ENV {
    static e := &ENV(nil)
    if e == nil {
        rv := C.db_env_create(&e, 0)
        assert rv==0
        e.set_alloc(e, malloc, v_realloc, free)
        flags := CREATE
        e.open(e, nil, flags, 0)
    }
    return e
}

pub fn (db &DB) closex(wt u32) {
    rv := db.close(db, wt)
    assert rv == 0
}
pub fn (db &DB) openx(file string, typ int, flags u32) ! {
    flags |= u32(THREAD)
	flags |= u32(CREATE)
	flags |= u32(NOMMAP)
	// flags |= u32(RECNUM)

    rv0 := db.set_flags(db, RECNUM)
    assert rv0 == 0, strerror(rv0)
    // rv1 := db.set_flags(db, TXN_NOT_DURABLE)
    // assert rv1 == 0, strerror(rv1)
    
    rv := db.open(db, nil, file.str, nil, typ, flags, 0)
    assert rv == 0, strerror(rv)
}

// return count
pub fn (db &DB) truncatex() !u32 {
    cnt := u32(0)
    rv := db.truncate(db, nil, &cnt, 0)
    assert rv == 0, strerror(rv)
    return cnt
}

// before open
pub fn (db &DB) verifyx(file string) ! {
    rv := db.verify(db, file.str, nil, nil, 0)
    assert rv == 0, strerror(rv)
}

pub fn (db &DB) delx(key string) ! {
    k := DBT{data: key.str, size: u32(key.len+1)}

    rv := db.del(db, nil, &k, 0)
    assert rv == 0, strerror(rv)
}

pub fn (db &DB) has(key string) !bool {
    k := DBT{data: key.str, size: u32(key.len+1)}

    rv := db.exists(db, nil, &k, 0)
    if NOTFOUND == rv { return false }
    assert rv == 0, strerror(rv)
    return true
}

pub fn (db &DB) getx(key string) !(string, bool) {
    buf := [9999]i8{}
    
    k := DBT{data: key.str, size: u32(key.len+1)}
    // v := DBT{flags: DBT_USERMEM, ulen: 9999, data: &buf[0]}
    v := DBT{flags: DBT_MALLOC}

    rv := db.get(db, nil, &k, &v, 0)
    if NOTFOUND == rv { return '', false }
    assert rv == 0, strerror(rv)

    if use_v_alloc {
        return v.data.tosdup(int(v.size-1)), true
    } else {
        return v.data.tosfree(int(v.size-1)), true
    }
}

// anyway return recno without extra call?
pub fn (db &DB) putx(key string, val string, flags u32) ! {
    k := DBT{data: key.str, size: u32(key.len+1)}
    v := DBT{data: val.str, size: u32(val.len+1)}

    // flags := u32(NODUPDATA)
    flags |= NOOVERWRITE
    rv := db.put(db, nil, &k, &v, flags)
    assert rv == 0, strerror(rv)    
}

pub fn (db &DB) cursorx() !&DBC {
    c := &DBC(nil)
    rv := db.cursor(db, nil, &c, 0)
    assert rv == 0, strerror(rv)
    return c
}

pub fn (db &DB) count_byiter() !int {
    c := db.cursorx() !
    defer { c.closex() }

    pval := u32(0)
    k := DBT{flags: DBT_USERMEM}
    k.flags |= DBT_PARTIAL
    k.data = &pval
    k.ulen = sizeof(pval)
    
    v := DBT{flags: DBT_USERMEM}
    v.flags |= DBT_PARTIAL
    v.data = &pval
    v.ulen = sizeof(pval)

    cnt := 0
    for ;; cnt ++ {
        rv := c.get(c, &k, &v, NEXT)
        if NOTFOUND == rv { break }
        assert rv == 0, strerror(rv)
        assert k.size == 0 // because DBT_PARTIAL
        assert v.size == 0
    }

    return cnt
}

// no malloc, no data copy
pub fn (db &DB) count_byrecno() !int {
    c := db.cursorx() !
    defer { c.closex() }

    ok := c.set_last(false) !
    if !ok { return 0 }
    
    res := c.get_recno() !
    return int(res)
}

fn C.db_strerror(int) charptr
pub fn strerror(eno int) string {
    return C.db_strerror(eno).tosdup()
}

////////////////

pub fn (c &DBC) closex() {
    rv := c.close(c)
    assert rv == 0, strerror(rv)    
}

// too many useage by flags
// split to seperated methods
pub fn (c &DBC) getx() ! {
    
}

// no malloc, no data copy
pub fn (c &DBC) set_last(isfirst bool) ! bool {
    k := DBT{flags: DBT_READONLY}
    v := DBT{flags: DBT_USERMEM}
    v.flags |= DBT_PARTIAL
    v.ulen = 0

    flags := isfirst.ifor(FIRST, LAST)
    rv := c.get(c, &k, &v, flags)
    if NOTFOUND == rv { dump('not found $isfirst') }
    if NOTFOUND == rv { return false }
    assert rv == 0, strerror(rv)
    assert k.size == 0
    assert v.size == 0
    return true
}

// no malloc, no data copy
// usage `for c.next()! { c.get_recno(); c.get_kv() }`
pub fn (c &DBC) next(isprev bool) !bool {
    k := DBT{flags: DBT_READONLY}
    v := DBT{flags: DBT_PARTIAL}
    v.flags |= DBT_USERMEM
    v.ulen = 0

    flags := isprev.ifor(PREV, NEXT)
    rv := c.get(c, &k, &v, flags)
    if NOTFOUND == rv { return false }
    assert rv == 0, strerror(rv)
    assert v.data == nil
    return true
}

pub fn (c &DBC) get_recno() !u32 {
    res := u32(0)
    k := DBT{flags: DBT_READONLY} // ignored but cannot nil
    v := DBT{flags: DBT_USERMEM}
    v.data = &res
    v.ulen = sizeof(res)

    rv := c.get(c, &k, &v, GET_RECNO)
    assert rv == 0, strerror(rv)
    assert v.data == &res

    return res
}

pub fn (db &DB) get_recno(key string) !u32 {
    c := db.cursorx() !
    defer { c.closex() }
    
    k := DBT{flags: 0}
    k.data = key.str
    k.size = u32(key.len+1)
    k.ulen = u32(key.len+1)

    {
        v := DBT{flags: DBT_USERMEM}
        v.flags |= DBT_PARTIAL
        v.ulen = 0
        
        rv := c.get(c, &k, &v, SET)
        assert rv == 0, strerror(rv)
    }
    
    res := u32(0)
    {
        v := DBT{flags: DBT_USERMEM}
        v.data = &res
        v.ulen = sizeof(res)
        
        rv := c.get(c, &k, &v, GET_RECNO)
        assert rv == 0, strerror(rv)
    }
    
    return res
}
pub fn (db &DB) get_kv(recno u32) !(string,string) {
    c := db.cursorx() !
    defer { c.closex() }
    
    k := DBT{flags: DBT_MALLOC}
    k.data = &recno
    k.size = sizeof(recno)
    v := DBT{flags: DBT_MALLOC}

    assert recno > 0
    rv := c.get(c, &k, &v, SET_RECNO)
    assert rv == 0, strerror(rv) + ' ' + recno.str()

    if use_v_alloc {
        return k.data.tosdup(int(k.size-1)),
        v.data.tosdup(int(v.size-1))
    } else {
        return k.data.tosfree(int(k.size-1)),
        v.data.tosfree(int(v.size-1))
    }
}

pub fn (c &DBC) get_kv() !(string,string) {
    k := DBT{flags: DBT_MALLOC}
    v := DBT{flags: DBT_MALLOC}

    rv := c.get(c, &k, &v, CURRENT)
    assert rv == 0, strerror(rv)


    if use_v_alloc {
        return k.data.tosdup(int(k.size-1)),
        v.data.tosdup(int(v.size-1))
    } else {
        return k.data.tosfree(int(k.size-1)),
        v.data.tosfree(int(v.size-1))
    }
}

pub fn (db &DB) get_cachesizex() (usize, int) {
    gbytes := usize(0)
    bytes := usize(0)
    ncache := int(0)

    rv := db.get_cachesize(db, &u32(&gbytes), &u32(&bytes), &ncache)
    assert rv == 0, strerror(rv)
    return gbytes*bytes_gb + bytes, ncache
}

pub const bytes_gb = 1024*1024*1024

// ncache default 1
// totbytes default 256KB
pub fn (db &DB) set_cachesizex(totbytes usize, ncache int) {
    gbytes := totbytes/ bytes_gb
    bytes := totbytes % bytes_gb

    rv := db.set_cachesize(db, u32(gbytes), u32(bytes), ncache)
    assert rv == 0, strerror(rv)
}

pub fn (db &DB) syncx(flags u32) ! {
    rv := db.sync(db, flags)
    assert rv == 0, strerror(rv)    
}

pub fn (db &DB) env() &ENV {
    rv := db.get_env(db)
    assert rv != nil
    return rv
}

////////////

fn C.db_env_create(...voidptr) int
pub fn ENV.create(flags u32) &ENV {
    e := &ENV(nil)
    rv := C.db_env_create(&e, flags)
    assert rv == 0, strerror(rv)
    return e
}
pub fn (e &ENV) closex(flags u32) {
    rv := e.close(e, flags)
    assert rv == 0, strerror(rv)
}
pub fn (e &ENV) openx(db_home string, flags u32, mode int) ! {
    flags |= THREAD
    flags |= CREATE
    flags |= INIT_TXN
    flags |= RECOVER
    
    rv := e.open(e, db_home.str, flags, mode)
    assert rv == 0, strerror(rv)
}

pub fn (e &ENV) set_cache_maxx(totbytes usize) {
    assert totbytes > 1024
    
    gbytes := totbytes / bytes_gb
    bytes := totbytes % bytes_gb

    rv := e.set_cache_max(e, u32(gbytes), u32(bytes))
    assert rv == 0, strerror(rv)
}

fn C.db_version(...voidptr) charptr
pub fn version_str() string {
    return C.db_version(nil, nil, nil).tosref()
}
pub fn version_num() (int, int, int) {
    maj, min, pat := 0, 0, 0
    C.db_version(&maj, &min, &pat)
    return maj, min, pat
}

////////////////

// DBTYPE
pub const BTREE   = (C.DB_BTREE)
pub const HASH	  = (C.DB_HASH)
pub const RECNO	  = (C.DB_RECNO)
pub const QUEUE	  = (C.DB_QUEUE)
pub const UNKNOWN = (C.DB_UNKNOWN)

pub const DBT_MALLOC   = u32(C.DB_DBT_MALLOC)
pub const DBT_REALLOC  = u32(C.DB_DBT_REALLOC)
pub const DBT_USERMEM  = u32(C.DB_DBT_USERMEM)
pub const DBT_READONLY = u32(C.DB_DBT_READONLY)
pub const DBT_PARTIAL  = u32(C.DB_DBT_PARTIAL)

/*
 * DB access method and cursor operation values.  Each value is an operation
 * code to which additional bit flags are added.
 */
pub const AFTER 		   = u32(1)        // /* Dbc.put */
pub const APPEND		   = u32(2)        // /* Db.put */
pub const BEFORE		   = u32(3)        // /* Dbc.put */
pub const CONSUME		   = u32(4)        // /* Db.get */
pub const CONSUME_WAIT	   = u32(5)        // /* Db.get */
pub const CURRENT		   = u32(6)        // /* Dbc.get, Dbc.put, DbLogc.get */
pub const FIRST		       = u32(7)        // /* Dbc.get, DbLogc->get */
pub const GET_BOTH		   = u32(8)        // /* Db.get, Dbc.get */
pub const GET_BOTHC		   = u32(9)        // /* Dbc.get (internal) */
pub const GET_BOTH_RANGE   = u32(10)	      // /* Db.get, Dbc.get */
pub const GET_RECNO		   = u32(11)	      // /* Dbc.get */
pub const JOIN_ITEM		   = u32(12)	      // /* Dbc.get; don't do primary lookup */
pub const KEYFIRST		   = u32(13)       // /* Dbc.put */
pub const KEYLAST		   = u32(14)       // /* Dbc.put */
pub const LAST			   = u32(15)       // /* Dbc.get, DbLogc->get */
pub const NEXT			   = u32(16)       // /* Dbc.get, DbLogc->get */
pub const NEXT_DUP		   = u32(17)       // /* Dbc.get */
pub const NEXT_NODUP	   = u32(18)       // /* Dbc.get */
pub const NODUPDATA		   = u32(19)       // /* Db.put, Dbc.put */
pub const NOOVERWRITE	   = u32(20)       // /* Db.put */
pub const OVERWRITE_DUP	   = u32(21)       // /* Dbc.put, Db.put; no DB_KEYEXIST */
pub const POSITION		   = u32(22)       // /* Dbc.dup */
pub const PREV			   = u32(23)       // /* Dbc.get, DbLogc->get */
pub const PREV_DUP		   = u32(24)       // /* Dbc.get */
pub const PREV_NODUP	   = u32(25)       // /* Dbc.get */
pub const SET			   = u32(26)       // /* Dbc.get, DbLogc->get */
pub const SET_RANGE		   = u32(27)       // /* Dbc.get */
pub const SET_RECNO		   = u32(28)       // /* Db.get, Dbc.get */
pub const UPDATE_SECONDARY = u32(29)      // /* Dbc.get, Dbc.del (internal) */
pub const SET_LTE		   = u32(30)      // /* Dbc.get (internal) */
pub const GET_BOTH_LTE	   = u32(31)      // /* Dbc.get (internal) */

// to change when the max opcode hits 255. */
pub const OPFLAGS_MASK	  = u32(0x000000ff)   //	/* Mask for operations flags. */

/////
pub const AM_CHKSUM		        = u32(0x00000001)  //  /* Checksumming */
pub const AM_COMPENSATE	        = u32(0x00000002)  //  /* Created by compensating txn */
pub const AM_COMPRESS		    = u32(0x00000004)  //  /* Compressed BTree */
pub const AM_CREATED		    = u32(0x00000008)  //  /* Database was created upon open */
pub const AM_CREATED_MSTR	    = u32(0x00000010)  //  /* Encompassing file was created */
pub const AM_DBM_ERROR		    = u32(0x00000020)  //  /* Error in DBM/NDBM database */
pub const AM_DELIMITER		    = u32(0x00000040)  //  /* Variable length delimiter set */
pub const AM_DISCARD		    = u32(0x00000080)  //  /* Discard any cached pages */
pub const AM_DUP		        = u32(0x00000100)  //  /* DB_DUP */
pub const AM_DUPSORT		    = u32(0x00000200)  //  /* DB_DUPSORT */
pub const AM_ENCRYPT		    = u32(0x00000400)  //  /* Encryption */
pub const AM_FIXEDLEN		    = u32(0x00000800)  //  /* Fixed-length records */
pub const AM_INMEM		        = u32(0x00001000)  //  /* In-memory; no sync on close */
pub const AM_INORDER		    = u32(0x00002000)  //  /* DB_INORDER */
pub const AM_IN_RENAME		    = u32(0x00004000)  //  /* File is being renamed */
pub const AM_NOT_DURABLE	    = u32(0x00008000)  //  /* Do not log changes */
pub const AM_OPEN_CALLED	    = u32(0x00010000)  //  /* DB->open called */
pub const AM_PAD		        = u32(0x00020000)  //  /* Fixed-length record pad */
pub const AM_PARTDB		        = u32(0x00040000)  //  /* Handle for a database partition */
pub const AM_PGDEF		        = u32(0x00080000)  //  /* Page size was defaulted */
pub const AM_RDONLY		        = u32(0x00100000)  //  /* Database is readonly */
pub const AM_READ_UNCOMMITTED	= u32(0x00200000)  //  /* Support degree 1 isolation */
pub const AM_RECNUM		        = u32(0x00400000)  //  /* DB_RECNUM */
pub const AM_RECOVER		    = u32(0x00800000)  //  /* DB opened by recovery routine */
pub const AM_RENUMBER		    = u32(0x01000000)  //  /* DB_RENUMBER */
pub const AM_REVSPLITOFF	    = u32(0x02000000)  //  /* DB_REVSPLITOFF */
pub const AM_SECONDARY		    = u32(0x04000000)  //  /* Database is a secondary index */
pub const AM_SNAPSHOT		    = u32(0x08000000)  //  /* DB_SNAPSHOT */
pub const AM_SUBDB		        = u32(0x10000000)  //  /* Subdatabases supported */
pub const AM_SWAP		        = u32(0x20000000)  //  /* Pages need to be byte-swapped */
pub const AM_TXN		        = u32(0x40000000)  //  /* Opened in a transaction */
pub const AM_VERIFYING		    = u32(0x80000000)  //  /* DB handle is in the verifier */


/*
 * DB (user visible) error return codes.
 *
 * !!!
 * We don't want our error returns to conflict with other packages where
 * possible, so pick a base error value that's hopefully not common.  We
 * document that we own the error name space from -30,800 to -30,999.
 */
/* DB (public) error return codes. */
pub const BUFFER_SMALL		= (-30999)    // /* User memory too small for return. */
pub const DONOTINDEX		= (-30998)    // /* "Null" return from 2ndary callbk. */
pub const FOREIGN_CONFLICT	= (-30997)    // /* A foreign db constraint triggered. */
pub const HEAP_FULL		    = (-30996)    // /* No free space in a heap file. */
pub const KEYEMPTY		    = (-30995)    // /* Key/data deleted or never created. */
pub const KEYEXIST		    = (-30994)    // /* The key/data pair already exists. */
pub const LOCK_DEADLOCK	    = (-30993)    // /* Deadlock. */
pub const LOCK_NOTGRANTED	= (-30992)    // /* Lock unavailable. */
pub const LOG_BUFFER_FULL	= (-30991)    // /* In-memory log buffer full. */
pub const LOG_VERIFY_BAD	= (-30990)    // /* Log verification failed. */
pub const META_CHKSUM_FAIL	= (-30989)    // /* Metadata page checksum failed. */
pub const NOSERVER		    = (-30988)    // /* Server panic return. */
pub const NOTFOUND		    = (-30987)    // /* Key/data pair not found (EOF). */
pub const OLD_VERSION		= (-30986)    // /* Out-of-date version. */
pub const PAGE_NOTFOUND	    = (-30985)    // /* Requested page not found. */
pub const REP_DUPMASTER	    = (-30984)    // /* There are two masters. */
pub const REP_HANDLE_DEAD	= (-30983)    // /* Rolled back a commit. */
pub const REP_HOLDELECTION	= (-30982)    // /* Time to hold an election. */
pub const REP_IGNORE		= (-30981)    // /* This msg should be ignored.*/
pub const REP_ISPERM		= (-30980)    // /* Cached not written perm written.*/
pub const REP_JOIN_FAILURE	= (-30979)    // /* Unable to join replication group. */
pub const REP_LEASE_EXPIRED	= (-30978)    // /* Master lease has expired. */
pub const REP_LOCKOUT		= (-30977)    // /* API/Replication lockout now. */
pub const REP_NEWSITE		= (-30976)    // /* New site entered system. */
pub const REP_NOTPERM		= (-30975)    // /* Permanent log record not written. */
pub const REP_UNAVAIL		= (-30974)    // /* Site cannot currently be reached. */
pub const REP_WOULDROLLBACK	= (-30973)    // /* UNDOC: rollback inhibited by app. */
pub const RUNRECOVERY		= (-30972)    // /* Panic return. */
pub const SECONDARY_BAD	    = (-30971)    // /* Secondary index corrupt. */
pub const SLICE_CORRUPT	    = (-30970)    // /* A part of a sliced env is corrupt. */
pub const TIMEOUT		    = (-30969)    // /* Timed out on read consistency. */
pub const VERIFY_BAD		= (-30968)    // /* Verify failed; bad format. */
pub const ERSION_MISMATCH	= (-30967)    // /* Environment version mismatch. */
 
/* DB (private) error return codes. */
pub const ALREADY_ABORTED	= (-30899)    // /* Spare error number (-30898). */
pub const DELETED		    = (-30897)    // /* Recovery file marked deleted. */
pub const EVENT_NOT_HANDLED	= (-30896)    // /* Forward event to application. */
pub const NEEDSPLIT		    = (-30895)    // /* Page needs to be split. */
pub const NOINTMP		    = (-30886)    // /* Sequences not supported in temporary or in-memory databases. */
pub const REP_BULKOVF		= (-30894)    // /* Rep bulk buffer overflow. */
pub const REP_LOGREADY		= (-30893)    // /* Rep log ready for recovery. */
pub const REP_NEWMASTER	    = (-30892)    // /* We have learned of a new master. */
pub const REP_PAGEDONE		= (-30891)    // /* This page was already done. */
pub const SURPRISE_KID		= (-30890)    // /* Child commit where parent didn't know it was a parent. */
pub const SWAPBYTES		    = (-30889)    // /* Database needs byte swapping. */
pub const TXN_CKP		    = (-30888)    // /* Encountered ckp record in log. */
pub const VERIFY_FATAL		= (-30887)    // /* DB->verify cannot proceed. */

/*
 * This exit status indicates that a BDB utility failed because it needed a
 * resource which had been held by a process which crashed or otherwise did
 * not exit cleanly.
 */
pub const EXIT_FAILCHK		= 3


//////

// .open flags
pub const AUTO_COMMIT       = u32(C.DB_AUTO_COMMIT)
pub const CREATE            = u32(C.DB_CREATE)
pub const NOMMAP            = u32(C.DB_NOMMAP)
pub const RDONLY            = u32(C.DB_RDONLY)
pub const RECNUM            = u32(C.DB_RECNUM)
pub const RENUMBER          = u32(C.DB_RENUMBER)
pub const THREAD            = u32(C.DB_THREAD)
pub const TRUNCATE          = u32(C.DB_TRUNCATE)
pub const TXN_NOT_DURABLE   = u32(C.DB_TXN_NOT_DURABLE)
pub const VERIFY            = u32(C.DB_VERIFY)
pub const INIT_TXN          = u32(C.DB_INIT_TXN)
pub const RECOVER           = u32(C.DB_RECOVER)

