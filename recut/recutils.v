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


pub type Mset = C.rec_mset_s
// @[typedef]
pub struct C.rec_mset_s {}

pub type MsetElem = C.rec_mset_elem_s
// @[typedef]
pub struct C.rec_mset_elem_s {}

pub type MsetListIter = C.rec_mset_list_iter_t
@[typedef]
pub struct C.rec_mset_list_iter_t {
    pub mut:
}

pub type MsetIterator = C.rec_mset_iterator_t
@[typedef]
pub struct C.rec_mset_iterator_t {
    pub mut:
    mset &Mset = vnil
    list_iter MsetListIter
}

pub type MsetDispFn = fn(data voidptr)
pub type MsetEqualFn = fn(data1 voidptr, data2 voidptr) bool
pub type MsetDupFn = fn(data voidptr) voidptr
pub type MsetComparelFn = fn(data1 voidptr, data2 voidptr, type2 int) int

// drop !
fn dlsym0(name string) voidptr {
    return rtld.sym(name) or { vcp.error(err.str()) }
}

pub union CRetval {
    ircpp.CRetval
    set &Mset = vnil
    elem &MsetElem = vnil
}
const crv = &CRetval{} // used as ret arg

pub fn (set &Mset) str() string {
    _ = Anyer(crv.set) // V bug invalid use of incomplete typedef, need a custom str()    
    return "&${@STRUCT}(${voidptr(set)})"
}
pub fn (elem &MsetElem) str() string {
    _ = Anyer(crv.elem) // V bug invalid use of incomplete typedef, need a custom str()    
    return "&${@STRUCT}(${voidptr(elem)})"
}

fn function_missing(funcname string, args...Anyer) CRetval {
    fnp := dlsym0(funcname)
    return ffi.callany[CRetval](fnp, ...args)
}

// one line binding
// call foo(...) if all args can auto convert to Anyer
// call vcp.call_vatmpl(...) if that need extra dlsym  
// call ffi.callfca8(...) if that return not primitive type

pub fn new() &Mset {
    return rec_mset_new().set
}

pub fn (set &Mset) destroy() {
    rec_mset_destroy(set)
    // vcp.call_vatmpl(dlsym0('rec_mset_destroy'), 0, set) 
}

pub fn (set &Mset) dup() &Mset {
   return rec_mset_dup(set).set
    // return vcp.call_vatmpl(dlsym0('rec_mset_dup'), set, set)
    // return ffi.callfca8(dlsym0('rec_mset_dup'), set, set)
}

// Registering Types in a multi-set

pub type Type = int

pub fn (set &Mset) type_p(ty Type) bool {
    
    return vcp.call_vatmpl(dlsym0('rec_mset_type_p'), true, set, ty) 
}

pub fn (set &Mset) count(ty Type) usize {
    return rec_mset_count(set, int(ty)).usize
    // return vcp.call_vatmpl(dlsym0('rec_mset_count'), usize(0), set, ty) 
}

pub fn (set &Mset) register_type(name string) Type {
    return rec_mset_register_type(set, voidptr(name.str), vnil).int
    // fnp := dlsym0('rec_mset_register_type')
    // return vcp.call_vatmpl(fnp, Type(-1), set, name.str, vnil, vnil, vnil, vnil)
}

pub fn (set &Mset) get_at(ty Type, pos usize) voidptr {
    return rec_mset_get_at(set, int(ty), pos).vptr
    // fnp := dlsym0('rec_mset_get_at')
    // return vcp.call_vatmpl(fnp, vnil, set, ty, pos) 
}
pub fn (set &Mset) insert_at(ty Type, data voidptr, pos usize) &MsetElem {
    return rec_mset_insert_at(set, int(ty), data, pos).elem
    // fnp := dlsym0('rec_mset_insert_at')
    // return vcp.call_vatmpl(fnp, crv, set, ty, data, pos).elem
}
pub fn (set &Mset) insert_after(ty Type, data voidptr, elem &MsetElem) &MsetElem {
    return rec_mset_insert_after(set, int(ty), data, elem).elem
    // fnp := dlsym0('rec_mset_insert_after')
    // return vcp.call_vatmpl(fnp, crv, set, ty, data, elem).elem
}
pub fn (set &Mset) append(ty Type, data voidptr) &MsetElem {
    return rec_mset_append(set, int(ty), data).elem
    // fnp := dlsym0('rec_mset_append')
    // return vcp.call_vatmpl(fnp, crv, set, ty, data, ty).elem
}
pub fn (set &Mset) add_sorted(ty Type, data voidptr) &MsetElem {
    return rec_mset_add_sorted(set, int(ty), data).elem
    // fnp := dlsym0('rec_mset_add_sorted')
    // return vcp.call_vatmpl(fnp, crv, set, ty, data).elem
}

pub fn (set &Mset) remove_elem(ty Type, elem &MsetElem) bool {
    return rec_mset_remove_elem(set, int(ty), elem).bool
    // fnp := dlsym0('rec_mset_remove_elem')
    // return vcp.call_vatmpl(fnp, true, set, ty, elem)
}
pub fn (set &Mset) remove_at(ty Type, pos usize) bool {
    return rec_mset_remove_at(set, int(ty), pos).bool
    // fnp := dlsym0('rec_mset_remove_at')
    // return vcp.call_vatmpl(fnp, true, set, ty, pos)
}

pub fn (set &Mset) search(data voidptr) &MsetElem {
    return rec_mset_search(set, data).elem
    // fnp := dlsym0('rec_mset_search')
    // return vcp.call_vatmpl(fnp, crv, set, data).elem
}

/*************** Iterating on mset elements *************************/

pub fn (set &Mset) iterator() MsetIterator {
    fnp := dlsym0('rec_mset_iterator')
    return vcp.call_vatmpl(fnp, MsetIterator{}, set)
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
