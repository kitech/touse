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

pub fn (me &Env) symbol_value(varname string) Value {
	rv := me.fcall2(funame2el(@FN), me.intern(varname))
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

pub fn funame2el(name string) string {
	s := name.camel_to_snake()
	s = s.replace('_', '-')
	// vcp.info(name, '=>', s)
	return s
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
