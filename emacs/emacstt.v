module emacs

import vcp

// some test functions

fn basictt(env &Env) {
	tv := env.intval(123)
	vcp.info('envfn:', tv)
	vcp.info(tv.isnil(env))
	vcp.info(tv.toint(env))
	vcp.info(tv.toint(env)) // why zero

	v := env.strval('abcd')
	vcp.info(v.isnil(env))
	assert env.fcall2('stringp', v).isnil(env) == false
	s := v.tostr(env)
	vcp.info(s)

	tv2 := env.intern('hehehe-intern')
	env.chkret()
	ty := tv2.typof(env) // symbol?
	env.chkret()
	if true {
		rv := env.fcall(env.intern('stringp'), tv2)
		vcp.info(rv.isnil(env), rv.strfy(env))
		assert rv.isnil(env) == true
		rv = env.fcall(env.intern('symbolp'), tv2)
		vcp.info(rv.isnil(env), rv.strfy(env))
		assert rv.isnil(env) == false
	}
	vcp.info(tv2.strfy(env))

	vcp.info(ty.isnil(env))
	vcp.info(ty.strfy(env))
	env.chkret()

	// this test code, move here
	tcons := env.cons2(1, 1.2, '3.4')
	vcp.info(tcons.strfy(env))

	// todo --module-assertions failed
	// env.fcall3('set', Symbol('tool-bar-mode'), vnil)
	// env.fcall3('setq-local', Symbol('tool-bar-mode'), 'off')

	vcp.info(env.fcall3('symbol-value', Symbol('tool-bar-mode')))
}

fn funcstt(env &Env) {
	fun := fn (e &Env) {
		vcp.info('test clos fun callback from emacs')
	}
	elfn := env.funval(fun)
	// elfn = env.globref(elfn) // not need
	vcp.info(env.typof(elfn)) // module-function
	env.fcall(elfn)

	symname := veclosnext()
	vcp.info(symname)

	env.fcall3('defalias', env.intern(symname), elfn)
	// env.fcall3('fset', env.intern(symname), elfn)
	symin := env.intern(symname)
	env.fcall(symin)
	// rv := env.fcall3(me.funame2el(@FN), Symbol(hook), elfn)
	// rv := env.fcall3(me.funame2el(@FN), Symbol(hook), symin)
	env.nle_check()
}
