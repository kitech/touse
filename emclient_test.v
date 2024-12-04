module emacs

import vcp

fn test_1() {
}

fn test_2() {
	runon_uithread(fn (e &Env, args []Value) Value {
		vcp.info('ehehe', e.asptr())
		return emvs.eltrue
	}, false, 1.2, f32(123), 'abc', 42)

	assert false
}
