module recut

import vcp
import vcp.rtld

#include <rec.h>

pub fn init_() {
    // rtld.add_libpath("")
    rtld.link('rec') or { vcp.error(err.str()) }
    vcp.info(rtld.ldd())
    vcp.call_vatmpl(dlsym0('rec_init'), 0)
}
pub fn fini() {
    vcp.call_vatmpl(dlsym0('rec_fini'), 0)
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
    mset &Mset
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

pub fn new() &Mset {
    fnp := dlsym0('rec_mset_new')
    rv := voidptr(vnil)
    rv = vcp.call_vatmpl(fnp, rv)
    return &Mset(rv)
}

pub fn (set &Mset) destroy() {
    fnp := dlsym0('rec_mset_destroy')
    vcp.call_vatmpl(fnp, 0, set) 
}

pub fn (set &Mset) dup() &Mset {
    fnp := dlsym0('rec_mset_dup')
    rv := &Mset(vnil)
    return vcp.call_vatmpl(fnp, rv, set) 
}


// Registering Types in a multi-set

pub type Type = int

pub fn (set &Mset) type_p(ty Type) bool {
    fnp := dlsym0('rec_mset_type_p')
    return vcp.call_vatmpl(fnp, true, set, ty) 
}

pub fn (set &Mset) count(ty Type) usize {
    fnp := dlsym0('rec_mset_count')
    return vcp.call_vatmpl(fnp, usize(0), set, ty) 
}

pub fn (set &Mset) register_type(name string) Type {
    fnp := dlsym0('rec_mset_register_type')
    return vcp.call_vatmpl(fnp, Type(-1), set, name.str, vnil, vnil, vnil, vnil)
}

pub fn (set &Mset) get_at(ty Type, pos usize) voidptr {
    fnp := dlsym0('rec_mset_get_at')
    return vcp.call_vatmpl(fnp, vnil, set, ty, pos) 
}
pub fn (set &Mset) insert_at(ty Type, data voidptr, pos usize) &MsetElem {
    fnp := dlsym0('rec_mset_insert_at')
    return vcp.call_vatmpl(fnp, &MsetElem(vnil), set, ty, data, pos) 
}
pub fn (set &Mset) insert_after(ty Type, data voidptr, elem &MsetElem) &MsetElem {
    fnp := dlsym0('rec_mset_insert_after')
    return vcp.call_vatmpl(fnp, &MsetElem(vnil), set, ty, data, elem) 
}
pub fn (set &Mset) append(ty Type, data voidptr) &MsetElem {
    fnp := dlsym0('rec_mset_append')
    return vcp.call_vatmpl(fnp, &MsetElem(vnil), set, ty, data, ty)
}
pub fn (set &Mset) add_sorted(ty Type, data voidptr) &MsetElem {
    fnp := dlsym0('rec_mset_add_sorted')
    return vcp.call_vatmpl(fnp, &MsetElem(vnil), set, ty, data)
}

pub fn (set &Mset) remove_elem(ty Type, elem &MsetElem) bool {
    fnp := dlsym0('rec_mset_remove_elem')
    return vcp.call_vatmpl(fnp, true, set, ty, elem)
}
pub fn (set &Mset) remove_at(ty Type, pos usize) bool {
    fnp := dlsym0('rec_mset_remove_at')
    return vcp.call_vatmpl(fnp, true, set, ty, pos)
}

pub fn (set &Mset) search(data voidptr) &MsetElem {
    fnp := dlsym0('rec_mset_search')
    return vcp.call_vatmpl(fnp, &MsetElem(vnil), set, data)
}

/*************** Iterating on mset elements *************************/

pub fn (set &Mset) iterator() MsetIterator {
    fnp := dlsym0('rec_mset_iterator')
    return vcp.call_vatmpl(fnp, MsetIterator{}, set)
}

pub fn (itr &MsetIterator) next(ty Type, data &voidptr, elem &&MsetElem) bool {
    fnp := dlsym0('rec_mset_iterator_next')
    return vcp.call_vatmpl(fnp, true, itr, data, elem)
}

pub fn (itr &MsetIterator) free() {
    fnp := dlsym0('rec_mset_iterator_free')
    vcp.call_vatmpl(fnp, true, itr)
}


/*************** Managing mset elements ******************************/
