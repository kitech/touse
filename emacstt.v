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

	env.fcall3('set', Symbol('tool-bar-mode'), vnil) // works
	// env.fcall3('setq-local', Symbol('tool-bar-mode'), 'off')
	vcp.info(env.fcall3('symbol-value', Symbol('tool-bar-mode')))
}
