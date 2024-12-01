module emacs

import vcp

// symbol, lispsym
// sym2 := vcp.dlsym0('lispsym')
// vcp.info(sym2)

// v is derefed Value
pub fn islispobj(v voidptr) int {
	sym2 := vcp.dlsym0('valid_lisp_object_p')
	// vcp.info(sym2)
	fno2 := funcof(sym2, fn (_ voidptr) int {
		return 0
	})

	rv2 := fno2(voidptr(v))
	//	vcp.info(rv2)
	return rv2
}

///
pub fn (e &Env) car(v Value) Value {
	return e.fcall2('car', v)
}

pub fn (e &Env) cdr(v Value) Value {
	return e.fcall2('cdr', v)
}

pub fn (e &Env) first(v Value) Value {
	return e.fcall2('car', v)
}

pub fn (e &Env) rest(v Value) Value {
	return e.fcall2('cdr', v)
}

pub fn (e &Env) cons2arr(v Value) []Value {
	rv := []Value{}
	t := v
	for !t.isnil(e) {
		a := e.car(t)
		rv << a
		t = e.cdr(t)
	}
	return rv
}

pub fn (e &Env) mapcar(v Value, cb fn (Value) Value) []Value {
	rv := []Value{}
	t := v
	for !t.isnil(e) {
		a := e.car(t)
		rv << cb(a)
		t = e.cdr(t)
	}
	return rv
}

pub fn (e &Env) conslen(v Value) int {
	rv := 0
	t := v
	for !t.isnil(e) {
		rv++
		t = e.cdr(t)
	}
	return rv
}

pub fn (e &Env) cons(vals ...Value) Value {
	assert vals.len > 0
	rv := vals[vals.len - 1]
	for i := vals.len - 2; i >= 0; i-- {
		rv = e.fcall2(funame2el(@FN), vals[i], rv)
	}
	return rv
}

pub fn (e &Env) cons2(vals ...Anyer) Value {
	elvs := []Value{len: vals.len}
	for idx, val in vals {
		tv := e.toel(val)
		elvs[idx] = tv
	}
	rv := e.cons(...elvs)
	assert rv.typof(e).strfy(e) == 'cons'
	return rv
}

// assoc list
pub fn (e &Env) alist(kvs map[string]Value) Value {
	items := []Value{len: kvs.len}
	cnt := 0
	for k, v in kvs {
		item := e.cons(e.intern(k), v)
		items[cnt++] = item
	}
	rv := e.fcall2('list', ...items)
	rvty := rv.typof(e).strfy(e)
	// vcp.info(rvty)
	// assert rvty == 'cons'
	return rv
}

// assoc list
pub fn (e &Env) alist2(kvs map[string]Anyer) Value {
	mt := map[string]Value{}
	for k, v in kvs {
		mt[k] = e.toel(v)
	}
	return e.alist(mt)
}

// assoc list
// useful when only several args that less than 5
// key must string
// k1, v1, v2, v2, ...
pub fn (e &Env) alist3(kvs ...Anyer) Value {
	assert kvs.len % 2 == 0
	mt := map[string]Value{}
	for i := 0; i < kvs.len; i += 2 {
		kx, vx := kvs[i], kvs[i + 1]
		k := kx as string
		mt[k] = e.toel(vx)
	}
	return e.alist(mt)
}

// need varidic template function definition
// pub fn (e &Env) alist0[T,U,V,W,X,Y,X](...) {}
pub fn (e &Env) alist0() {
}

pub fn (e &Env) add_to_list(v Value, item Value) {
	e.fcall2(funame2el(@FN), v, item)
}

pub fn (v Value) symbol_name(e &Env) string {
	rv := e.fcall2(funame2el(@FN), v)
	return rv.tostr(e)
}
