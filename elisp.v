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

pub fn (e &Env) cons(vals ...Value) Value {
	rv := emvs.elnil
	for i := vals.len - 1; i >= 0; i-- {
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
