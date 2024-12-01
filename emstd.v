module emacs

import vcp

// emacs std funcs, not in emacs-module.h
// set, stringp, integerp, symbolp ...
// descript-variable, ...

pub fn (me Value) descfy() {
	// describe-variable
}

// pub fn (me &Env) setvar() {
// }
pub fn (me &Env) getvar(varname string) Value {
	return me.symbol_value(varname)
}

// fix errmsg: symbol's value as variable is void
// only used for variable? no func?
pub fn (me &Env) boundp(v ElsymType) bool {
	varsym := match v {
		Symbol { me.intern(v) }
		string { me.intern(v) }
		Value { v }
	}
	tv := me.vm.funcall(me, me.intern('boundp'), 1, &varsym)
	// tv := me.fcall2('boundp', varsym) // some infinit recursive
	return !tv.isnil(me)
}

pub fn (me &Env) symbol_value(varname string) Value {
	varsym := me.intern(varname)
	// fix errmsg: symbol's value as variable is void
	if !me.boundp(varname) {
		return emvs.elvoid
	}

	rv := me.fcall2(funame2el(@FN), varsym)
	me.nle_check()
	if rv == vnil {
	}
	// vcp.info(rv.isnil(me), voidptr(rv), tv.isnil(me), varname)
	if rv.typof(me).strfy(me) == 'symbol' {
		// rv = me.fcall2(funame2el(@FN), rv)
	}
	return rv
}

pub fn (me &Env) symbol_value2(v Value) Value {
	varsym := v
	rv := me.fcall2('symbol-value', varsym)
	me.nle_check()
	if rv == vnil {
	}
	// vcp.info(rv.isnil(me), voidptr(rv), tv.isnil(me), varname)
	if rv.typof(me).strfy(me) == 'symbol' {
		// rv = me.fcall2(funame2el(@FN), rv)
	}
	return rv
}

pub fn (me &Env) funame2el(name string) Value {
	s := funame2el(name)
	rv := me.intern(s)
	return rv
}

// func/sym name to el
pub fn funame2el(name string) string {
	s := name.camel_to_snake()
	s = s.replace('_', '-')
	// vcp.info(name, '=>', s)
	return s
}

// func/sym name from el
pub fn nameofel(name string, camel bool) string {
	return name.replace('-', '_')
}

fn veclosnext() string {
	refvar2mut(emvs).elclostmpno += 3
	return 'veclos${emvs.elclostmpno}'
}

// todo return error
pub fn (me &Env) add_hook(hook string, fun fn (e &Env)) {
	elfn := me.funval(fun)
	rv := me.fcall3(funame2el(@FN), Symbol(hook), elfn)
	me.nle_check()
}

// pub type DefunType = ...

// todo fun support more types
// todo return error
// fun, fn(&Env) // , voidptr, usize, FunctionData
pub fn (me &Env) defun(funame string, fun fn (e &Env), doc string) {
	fun0 := voidptr(fun)
	$if T is $function {
	} $else {
		vcp.warn('must specify a fn(..)', typeof(fun).name)
		return
	}
}

pub fn (me &Env) global_set_key(keys string, funame string) {
	rv1 := me.fcall2('kbd', me.strval(keys))
	me.fcall3(funame2el(@FN), rv1, Symbol(funame))
	me.nle_check()
}

///

pub fn (me &Env) anyp(vx Value) {
	pfuncs := ['consp', 'atom', 'null', 'listp', 'nlistp', 'arrayp', 'bool-vector-p', 'bufferp',
		'byte-code-function-p', 'case-table-p', 'char-or-string-p', 'char-table-p', 'commandp',
		'display-table-p', 'floatp', 'frame-configuration-p', 'frame-live-p', 'framep', 'functionp',
		'hash-table-p', 'integer-or-marker-p', 'integerp', 'keymapp', 'keywordp', 'markerp',
		'wholenump', 'numberp', 'number-or-marker-p', 'overlayp', 'processp', 'sequencep', 'stringp',
		'subrp', 'symbolp', 'syntax-table-p', 'user-variable-p', 'vectorp', 'window-configuration-p',
		'window-live-p', 'windowp', 'booleanp', 'string-or-null-p']
	// type-of, class-of
	for idx, pf in pfuncs {
		rv := me.fcall2(pf, vx)
		if !rv.isnil(me) {
			vcp.info(idx.str(), rv.isnil(me), pf.str())
		}
	}
	if false {
		rv := me.fcall2('type-of', vx)
		vcp.info(rv.strfy(me))
	}
}
