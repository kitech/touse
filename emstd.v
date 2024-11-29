module emacs

import vcp

// emacs std funcs, not in emacs-module.h
// set, stringp, integerp, symbolp ...
// descript-variable, ...

pub fn (me Value) desc() {
	// describe-variable
}

// pub fn (me &Env) set() {
// }

pub fn (me &Env) funame2el(name string) string {
	s := name.camel_to_snake()
	s = s.replace('_', '-')
	vcp.info(name, '=>', s)
	return s
	// rv := me.intern(s)
	// return rv
}

fn veclosnext() string {
	refvar2mut(emvs).elclostmpno += 3
	return 'veclos${emvs.elclostmpno}'
}

pub fn (me &Env) add_hook(hook string, fun fn ()) {
	x := voidptr(vnil)
	y := usize(0)

	elfn := me.funval(fun)
	elfn = me.globref(elfn)
	// me.fcall(elfn) // 在这还不能直接fcall,需要intern???
	vcp.info(me.typof(elfn)) // module-function
	me.fcall(elfn)

	symname := veclosnext()
	vcp.info(symname)
	me.fcall3('defalias', me.intern(symname), elfn)
	// me.fcall3('fset', me.intern(symname), elfn)
	symin := me.intern(symname)
	me.fcall(symin)
	// rv := me.fcall3(me.funame2el(@FN), Symbol(hook), elfn)
	// rv := me.fcall3(me.funame2el(@FN), Symbol(hook), symin)
	me.nle_check()
}
