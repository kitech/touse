module recut

import vcp
import vcp.rtld
import vcp.ircpp
import touse.ffi


#include <rec.h>

pub fn init_() {
    // rtld.add_libpath("")
    rtld.link('rec') or { vcp.error(err.str()) }
    vcp.info(rtld.ldd())
    // vcp.call_vatmpl(dlsym0('rec_init'), 0)
    rec_init()
}
pub fn fini() {
    rec_fini()
    // vcp.call_vatmpl(dlsym0('rec_fini'), 0)
}


// pub type Mset = C.rec_mset_s
// // @[typedef]
// pub struct C.rec_mset_s {}

// pub type MsetElem = C.rec_mset_elem_s
// // @[typedef]
// pub struct C.rec_mset_elem_s {}

pub type MsetListIter = C.rec_mset_list_iter_t
@[typedef]
pub struct C.rec_mset_list_iter_t {
    pub mut:
}

pub type MsetIterator = C.rec_mset_iterator_t
@[typedef]
pub struct C.rec_mset_iterator_t {
    pub mut:
    mset Mset
    list_iter MsetListIter
}

pub type Mset = usize
pub type MsetElem = usize
pub type Buf = usize
pub type Fex = usize
pub type FexElem = usize
pub type Field = usize
pub type Record = usize
pub type Rset = usize
pub type Sex = usize
pub type DB = usize
pub type Parser = usize
pub type Writer = usize

pub fn (v Mset) vptr() voidptr { return voidptr(v) }
pub fn (v MsetElem) vptr() voidptr { return voidptr(v) }
pub fn (v Field) vptr() voidptr { return voidptr(v) }
pub fn (v Record) vptr() voidptr { return voidptr(v) }
pub fn (v Rset) vptr() voidptr { return voidptr(v) }
pub fn (v DB) vptr() voidptr { return voidptr(v) }
pub fn (v Parser) vptr() voidptr { return voidptr(v) }
pub fn (v Writer) vptr() voidptr { return voidptr(v) }

pub type MsetDispFn = fn(data voidptr)
pub type MsetEqualFn = fn(data1 voidptr, data2 voidptr) bool
pub type MsetDupFn = fn(data voidptr) voidptr
pub type MsetComparelFn = fn(data1 voidptr, data2 voidptr, type2 int) int

// drop !
fn dlsym0(name string) voidptr {
    return rtld.sym(name) or { vcp.error(err.str()) }
}

pub union Retval {
    ircpp.Retval
pub:
    set Mset
    elem MsetElem
    
    buf Buf
    fld Field
    rset Rset
    rec Record
    db DB
    prs Parser
    wrs Writer
    
}
const crv = &Retval{} // used as ret arg

pub fn (set &Mset) str() string {
    _ = Anyer(crv.set) // V bug invalid use of incomplete typedef, need a custom str()    
    return "&${@STRUCT}(${voidptr(set)})"
}
pub fn (elem &MsetElem) str() string {
    _ = Anyer(crv.elem) // V bug invalid use of incomplete typedef, need a custom str()    
    return "&${@STRUCT}(${voidptr(elem)})"
}

fn function_missing(funcname string, args...Anyer) Retval {
    fnp := dlsym0(funcname)
    return ffi.callany[Retval](fnp, ...args)
}

// one line binding
// call foo(...) if all args can auto convert to Anyer
// call vcp.call_vatmpl(...) if that need extra dlsym  
// call ffi.callfca8(...) if that return not primitive type

pub fn new() Mset {
    return rec_mset_new().set
}

pub fn (set Mset) destroy() {
    rec_mset_destroy(set.vptr())
}

pub fn (set Mset) dup() Mset {
   return rec_mset_dup(set.vptr()).set
}

// Registering Types in a multi-set

pub type Type = int

pub fn (set Mset) type_p(ty Type) bool {    
    return vcp.call_vatmpl(dlsym0('rec_mset_type_p'), true, set, ty) 
}

pub fn (set Mset) count(ty Type) usize {
    return rec_mset_count(set.vptr(), int(ty)).usize
}

pub fn (set Mset) register_type(name string) Type {
    return rec_mset_register_type(set.vptr(), voidptr(name.str), vnil).int
}

pub fn (set Mset) get_at(ty Type, pos usize) voidptr {
    return rec_mset_get_at(set.vptr(), int(ty), pos).vptr
}
pub fn (set Mset) insert_at(ty Type, data voidptr, pos usize) MsetElem {
    return rec_mset_insert_at(set.vptr(), int(ty), data, pos).elem
}
pub fn (set Mset) insert_after(ty Type, data voidptr, elem MsetElem) MsetElem {
    return rec_mset_insert_after(set.vptr(), int(ty), data, elem.vptr()).elem
}
// data, Field/Comment/...
pub fn (set Mset) append(ty Type, data voidptr) MsetElem {
    return rec_mset_append(set.vptr(), int(ty), data, int(0)).elem
}
pub fn (set Mset) add_sorted(ty Type, data voidptr) MsetElem {
    return rec_mset_add_sorted(set.vptr(), int(ty), data).elem
}

pub fn (set Mset) remove_elem(ty Type, elem MsetElem) bool {
    return rec_mset_remove_elem(set.vptr(), int(ty), elem.vptr()).bool
}
pub fn (set Mset) remove_at(ty Type, pos usize) bool {
    return rec_mset_remove_at(set.vptr(), int(ty), pos).bool
}

pub fn (set Mset) search(data voidptr) MsetElem {
    return rec_mset_search(set.vptr(), data).elem
}

/*************** Iterating on mset elements *************************/

pub fn (set Mset) iterator() MsetIterator {
    fnp := dlsym0('rec_mset_iterator')
    return vcp.call_vatmpl(fnp, MsetIterator{}, set.vptr())
}

pub fn (itr &MsetIterator) next(ty Type, data &voidptr, elem &&MsetElem) bool {
    return rec_mset_iterator_next(itr, int(ty), data, elem).bool
    // fnp := dlsym0('rec_mset_iterator_next')
    // return vcp.call_vatmpl(fnp, true, itr, data, elem)
}

pub fn (itr &MsetIterator) free() {
    rec_mset_iterator_free(voidptr(itr))
    // fnp := dlsym0('rec_mset_iterator_free')
    // vcp.call_vatmpl(fnp, true, itr)
}


/*************** Managing mset elements ******************************/


/*************** Managing field  ******************************/


pub fn Field.new(name string, value string) Field {
    uv := rec_field_new(name.str.cptr(), value.str.cptr())
    return uv.fld
}

/*************** Managing record  ******************************/

pub fn Record.new() Record {
    return rec_record_new().rec
}
pub fn (rec Record) destroy() { rec_record_destroy(rec.vptr()) }

pub fn (rec Record) set_source(src string) {
    rec_record_set_source(rec.vptr(), src.str.cptr())
}
pub fn (rec Record) source() string {
    return rec_record_source(rec.vptr()).cptr.tosdup()
}
pub fn (rec Record) num_fields() usize {
    return rec_record_num_fields(rec.vptr()).usize
}
pub fn (rec Record) location_str() string {
    return rec_record_location_str(rec.vptr()).cptr.tosdup()
}
pub fn (rec Record) set_location(location usize)  {
    rec_record_location_str(rec.vptr(), location)
}
pub fn (rec Record) mset() Mset {
    return rec_record_mset(rec.vptr()).set
}
/*************** Managing mset elements ******************************/



/*************** DB/parser/writer ******************************/
pub fn DB.new() DB {
    return rec_db_new().db
}
pub fn (db DB) destroy() { rec_db_destroy(db) }
pub fn (db DB) size() usize { return rec_db_size(db.vptr()).usize }

pub fn (db DB) insert(typ string, rec Record) ! {
    idxp := nil
    random := usize(0)
    flags := 0
    uv := rec_db_insert(db.vptr(), typ.str.cptr(), idxp, nil, nil, random, nil, rec.vptr(), flags)
    if !uv.bool {
        return error('some error $typ')
    }
    dump(db.size())
}

pub fn (db DB) int_check() ! {
    uv := rec_int_check_db(voidptr(db), 1, 1, nil)
    if uv.int > 0 { return errorwc('some error', uv.int) }
}

pub fn Writer.new() Writer {
    uv := rec_writer_new(voidptr(C.stdout))
    // uv := rec_writer_new_str(voidptr(&wrbuf), voidptr(&bufsz))
    return uv.wrs
}
pub fn (wrs Writer) destroy()  { rec_writer_destroy(wrs.vptr()) }

pub fn (wrs Writer) write_db(db DB) ! {
    uv := rec_write_db(wrs.vptr(), db.vptr())
    if !uv.bool { return error ("some error dbb") }
}
pub fn (wrs Writer) write_field(fld Field) ! {
    uv := rec_write_field(wrs.vptr(), fld.vptr())
    if !uv.bool { return error ("some error field") }
}
pub fn (wrs Writer) write_record(fld Record) ! {
    uv := rec_write_record(wrs.vptr(), fld.vptr())
    if !uv.bool { return error ("some error record") }
}
pub fn (wrs Writer) write_str() ! {
    uv := rec_write_string(wrs.vptr(), c'ademo: strrr'.cptr())
    if !uv.bool { return error ("some error str") }
}
