module recut

import vcp
import vcp.xdl
import vcp.rtld
import vcp.ircpp
import touse.ffi


#include <rec.h>

pub const version_major = 1
pub const version_minor = 0

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

pub type Mset = voidptr
pub type MsetElem = voidptr
// pub type Buf = voidptr
pub type Fex = voidptr
pub type FexElem = voidptr
pub type Field = voidptr
pub type Record = voidptr
pub type Rset = voidptr
pub type Sex = voidptr
pub type DB = voidptr
pub type Parser = voidptr
pub type Writer = voidptr

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
    mset Mset
    mset_type MsetType
    elem MsetElem
    
    typ Type
    // buf Buf
    fld Field
    rset Rset
    rec Record
    db DB
    prs Parser
    wrs Writer
    
}
const crv = &Retval{} // used as ret arg

pub fn (set &Mset) str() string {
    _ = Anyer(crv.mset) // V bug invalid use of incomplete typedef, need a custom str()    
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

/*************** Managing mset elements ******************************/

// extendable by Mset.register_type, but rare use
pub enum MsetType {
    any = 0    // C.MSET_ANY
    field = 1   // C.MSET_FIELD
    // record = 1 // C.MSET_RECORD
    comment = 2 // C.MSET_COMMENT
}
pub enum RsetType {
    record = 1 // C.MSET_RECORD
}

pub fn Mset.new() Mset { return rec_mset_new().mset }
pub fn (set Mset) destroy() { rec_mset_destroy(set.vptr()) }
pub fn (set Mset) dup() Mset { return rec_mset_dup(set.vptr()).mset }

// Registering Types in a multi-set

pub fn (set Mset) type_p(ty MsetType) bool {    
    return vcp.call_vatmpl(dlsym0('rec_mset_type_p'), true, set, ty) 
}

pub fn (set Mset) count(ty MsetType) usize {
    return rec_mset_count(set.vptr(), int(ty)).usize
}

pub fn (set Mset) register_type(name string) MsetType {
    return rec_mset_register_type(set.vptr(), voidptr(name.str), vnil).mset_type
}

pub fn (set Mset) get_at(ty MsetType, pos usize) voidptr {
    return rec_mset_get_at(set.vptr(), int(ty), pos).vptr
}
pub fn (set Mset) insert_at(ty MsetType, data voidptr, pos usize) MsetElem {
    return rec_mset_insert_at(set.vptr(), int(ty), data, pos).elem
}
pub fn (set Mset) insert_after(ty MsetType, data voidptr, elem MsetElem) MsetElem {
    return rec_mset_insert_after(set.vptr(), int(ty), data, elem.vptr()).elem
}
// data, Field/Comment/...
pub fn (set Mset) append(ty MsetType, data voidptr) MsetElem {
    return rec_mset_append(set.vptr(), int(ty), data, int(0)).elem
}
pub fn (set Mset) add_sorted(ty MsetType, data voidptr) MsetElem {
    return rec_mset_add_sorted(set.vptr(), int(ty), data).elem
}

pub fn (set Mset) remove_elem(ty MsetType, elem MsetElem) bool {
    return rec_mset_remove_elem(set.vptr(), int(ty), elem.vptr()).bool
}
pub fn (set Mset) remove_at(ty MsetType, pos usize) bool {
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
    return rec_mset_iterator_next(voidptr(itr), int(ty), voidptr(data), voidptr(elem)).bool
    // fnp := dlsym0('rec_mset_iterator_next')
    // return vcp.call_vatmpl(fnp, true, itr, data, elem)
}

pub fn (itr &MsetIterator) free() {
    rec_mset_iterator_free(voidptr(itr))
    // fnp := dlsym0('rec_mset_iterator_free')
    // vcp.call_vatmpl(fnp, true, itr)
}

/*************** Managing field  ******************************/

// field type, primitive type, like int, double, bool, ...
// extenable with ..., but rare use
pub enum Type {
    none = 0 // C.REC_TYPE_NONE
    int =  1 // C.REC_TYPE_INT
    bool = 2
    range = 3
    real = 4
    // ...
}

pub fn Field.new(name string, value string) Field {
    assert name.count(' ') == 0 // cannot have ' ', see C.REC_FNAME_RE
    assert name.count('-') == 0
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
    return rec_record_mset(rec.vptr()).mset
}
/*************** Managing rset elements ******************************/

pub fn (set Rset) num_records() usize {
    return rec_rset_num_records(set.vptr()).usize
}

pub struct Buf {
    pub mut:
    cbuf voidptr

    data charptr // C.malloc memory, need free manual
    size usize    
}
pub fn Buf.new() &Buf {
    buf := &Buf{}
    uv := rec_buf_new(voidptr(&buf.data), voidptr(&buf.size))
    buf.cbuf = uv.vptr
    return buf
}
pub fn (buf &Buf) close() { rec_buf_close(buf.cbuf) }
pub fn (buf &Buf) rewind(n int) { rec_buf_rewind(buf.cbuf, n) }
pub fn (buf &Buf) string() string {
    return buf.data.tosref(int(buf.size))
}
pub fn (buf &Buf) put[T](v T) !{
    match v {
        i8 { rec_buf_putc(v, buf.cbuf) }
        string { rec_buf_puts(v.str.cptr(), buf.cbuf) }
        charptr { rec_buf_putc(v, buf.cbuf) }
        else{ return error("not impl ${typeof(v).name}")}
    }
}

/*************** DB/parser/writer ******************************/
pub fn DB.new() DB {
    return rec_db_new().db
}
pub fn (db DB) destroy() { rec_db_destroy(db.vptr()) }
pub fn (db DB) size() usize { return rec_db_size(db.vptr()).usize }

// typ can empty, then use 'default' type
pub fn (db DB) insert(typ string, rec Record) ! {
    typ2 := if typ.len==0 { 'default' } else { typ }
    if typ.len > 0 {
        assert typ.len>1
        assert typ[(typ.len-1) ..] in ['.', '+', '-'], typ // sowtt
    }

    idxp := nil
    random := usize(0)
    flags := 0
    uv := rec_db_insert(db.vptr(), typ2.str.cptr(), idxp, nil, nil, random, nil, rec.vptr(), flags)
    if !uv.bool {
        return error('some error $typ2')
    }
}

pub fn (db DB) int_check() ! {
    ebuf := Buf.new()
    defer { ebuf.close() }
    
    uv := rec_int_check_db(voidptr(db), 1, 1, ebuf.cbuf)
    if uv.int > 0 { return errorwc('some error: ${ebuf.string()}', uv.int) }
}

pub fn (db DB) get_rset(position usize) Rset {
    uv := rec_db_get_rset(db.vptr(), position)
    return uv.rset
}
pub fn (db DB) get_rset_by_type(typ string) Rset {
    uv := rec_db_get_rset_by_type(db.vptr(), typ.str.cptr())
    return uv.rset
}

pub fn Writer.new(fp &C.FILE) Writer {
    uv := rec_writer_new(voidptr(fp))
    return uv.wrs
}

// usage: buf, size := charptr(0), usize(0)
// Writer.new_str(&buf, &size)
// 
// both two are out param
// buf and size will fill when Writer.destroy
pub fn Writer.new_str(buf &charptr, size &usize) Writer {
    // !!! the second size param, must voidptr(size)
    uv := rec_writer_new_str(voidptr(buf), voidptr(size))
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


pub fn Parser.new(in_ &C.FILE, source string) Parser {
    uv := rec_parser_new(voidptr(in_), source.str.cptr())
    return uv.prs
}
// for not nulled buffer
pub fn Parser.new_mem(buf charptr, size usize, source string) Parser {
    uv := rec_parser_new_mem(buf, size, source.str.cptr())
    return uv.prs
}
pub fn Parser.new_str(buf string, source string) Parser {
    uv := rec_parser_new_str(buf.str.cptr(), source.str.cptr())
    return uv.prs
}
pub fn (prs Parser) destroy() { rec_parser_destroy(prs.vptr()) }
pub fn (prs Parser) reset() { rec_parser_reset(prs.vptr()) }
pub fn (prs Parser) error() bool { return rec_parser_error(prs.vptr()).bool }
pub fn (prs Parser) perror()  {
    caller_names := xdl.get_caller_names(true)
    rec_parser_perror(prs.vptr(), '${@FILE_LINE} <= ${caller_names[1]}'.str.cptr())
}

pub fn Parser.record_str(str string) !Record {
    uv := rec_parse_record_str(str.str.cptr())
    if uv.rec == 0 { return error('${@FILE_LINE}: ${@STRUCT}.${@FN} error') }
    return uv.rec
}
pub fn (prs Parser) record_str(str string) !Record {
    return Parser.record_str(str) !
}
pub fn (prs Parser) record() !Record {
    rec := Record(0)
    uv := rec_parse_record(prs.vptr(), voidptr(&rec))
    if !uv.bool { return error("${@FILE_LINE}: ${@STRUCT}.${@FN} error") }
    return rec
}
pub fn (prs Parser) db() !DB {
    db := DB(nil)
    uv := rec_parse_db(prs.vptr(), voidptr(&db))
    if !uv.bool {
        prs.perror()
        return error("${@FILE_LINE}: ${@STRUCT}.${@FN} error")
    }
    return db
}


/**************** Creating and destroying sexes ******************/



/**************** Encryption routines *******************************/
