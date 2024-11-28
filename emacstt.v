module emacs

import vcp

// some test functions

fn basictt() {
	env := emvs.env

	v := env.strval('abcd')
	vcp.info(v.isnil())
	assert env.fcall2('stringp', v).isnil() == false
	s := v.tostr()
	vcp.info(s)

	tv2 := env.intern('hehehe-intern')
	env.chkret()
	ty := tv2.typof() // symbol?
	env.chkret()
	if true {
		rv := env.fcall(env.intern('stringp'), tv2)
		vcp.info(rv.isnil(), rv.strfy())
		assert rv.isnil() == true
		rv = env.fcall(env.intern('symbolp'), tv2)
		vcp.info(rv.isnil(), rv.strfy())
		assert rv.isnil() == false
	}
	vcp.info(tv2.strfy())

	vcp.info(ty.isnil())
	vcp.info(ty.strfy())
	env.chkret()

	env.fcall3('set', Symbol('tool-bar-mode'), vnil) // works
	// env.fcall3('setq-local', Symbol('tool-bar-mode'), 'off')
	vcp.info(env.fcall3('symbol-value', Symbol('tool-bar-mode')))
}
